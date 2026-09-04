# infra 設計

## スコープ

本書は、Cloudflare 上のインフラ構成と、その運用手順を定義する。

次は定義しない。

* リポジトリ構成と、共通部分の配布・更新の仕組み
* コスト方針
* プロダクトのアプリケーション設計

## Cloudflare アカウントと環境

* 全プロダクトで単一の Cloudflare アカウントを共有する。zone はアカウントに帰属するため、1つのドメインのサブドメインをプロダクトへ割り当てる運用は単一アカウントでしか成立しない(サブドメインを独立 zone として分離する subdomain setup は Enterprise 限定)。
* アカウント ID は Terraform module の変数とし、プロダクト単位で別アカウントへ切り出せる形を保つ。Free の上限(D1 のデータベース数 10個、Cron Triggers 5個等)はアカウント単位で共有されるため、枠を枯渇させたプロダクトの退避経路を残す。
* 環境は production / preview の2つ。リソース命名は `<product>-<env>` で統一し、名前は Terraform が生成する。
* preview は D1 マイグレーションのリハーサルの場とし、production への適用前に必ず一度通す。スキーマ変更はコードと違いロールバックできない。
* wrangler の環境サフィックスなしのルート Worker は作らない。デプロイは常に `--env` を指定し、CI で強制する。
* Preview URL は preview 環境の Worker でのみ有効化する。Preview URL は対象バージョンが宣言する bindings で動くため、production の Worker に発行すると本番データに接続する。

## IaC の分界

| 管轄 | 対象 |
|---|---|
| Terraform | 消えると復旧できない長寿命リソース: zone / DNS / D1 / R2 / KV / API トークン / アカウント設定 |
| wrangler | 置き換え可能なもの: Worker のコード、bindings、ランタイムシークレット |

* wrangler の automatic provisioning は使用しない。
* Terraform state は R2 の S3 互換 backend に置く。state には API トークン等の秘密が平文で入るため、リポジトリには置かない。state 用バケットは非公開とし、専用トークンのみがアクセスできる。
* 手動で作成するのは state 用 R2 バケット1つとブートストラップ用 API トークン1つのみ。以降のリソースとトークンはすべて Terraform が作成する。

分界を跨いで Worker のデプロイを Terraform に載せると、PR ごとのデプロイと月数回のインフラ変更が同一 state を奪い合い、state ロックがデプロイのボトルネックになる。また Workers の versions / deployments による段階ロールアウトと即時ロールバックは wrangler 経由でのみ動く。

## CI/CD

* CI/CD は GitHub Actions に一本化する。lint / test / Terraform / wrangler deploy をすべて Actions で実行する。
* main へのマージで production まで全自動でデプロイする。
* ガードは人間の承認ではなく機械検査として置く。
  * `terraform plan` の結果に destroy または replace が含まれる場合、CI を失敗させる。実行するには明示フラグ付きの手動実行(`workflow_dispatch`)を用いる。
  * production への D1 マイグレーション適用の直前に、`wrangler d1 export` で現状を R2 へ退避してから適用する。
* production へのデプロイ順序: (1) マイグレーションがある場合は export で退避 → (2) `wrangler d1 migrations apply` → (3) `wrangler deploy`。
* コードのロールバックは wrangler の versions 機能で行う。

破壊的 SQL の静的検査は網羅できない。検出して止めるのではなく、退避によって復旧可能性を確保する。

## 権限とシークレット

Cloudflare API トークンは2本に分ける。日常的に動くワークフローが持つ権限を小さく保つ。

| トークン | 権限 | 利用箇所 |
|---|---|---|
| Terraform 用 | 広い(リソース・トークン発行を含む) | infra ワークフロー専用。GitHub Environment で参照元を限定する |
| デプロイ用 | Workers 系 + D1 編集 + Analytics Read | 通常のアプリワークフロー |

エクスポートの保存には、バックアップ用バケットに限定した専用トークン(`CLOUDFLARE_BACKUP_API_TOKEN`)を任意で受け付ける。Cloudflare の R2 権限はアカウント全体に及び、デプロイ用トークンに R2 編集を足すと state 用バケットにも届く。用意できるまではデプロイ用で代替でき、その場合はデプロイ用に R2 編集が要る。

アプリのランタイムシークレットは GitHub Secrets(環境ごと)を正とし、デプロイ時に CI が `wrangler secret put` で Cloudflare へ同期する。同期対象は命名規約(プレフィックス)で機械判定する。値そのものは記録しないが、キーの一覧と供給経路は再現可能に保つ。

## ストレージとバックアップ

* Terraform module のリソースはオプトインとする(`enable_d1` / `enable_r2` / `enable_kv` / `enable_static_assets`)。有効化したリソースにのみ、対応する運用(バックアップ、廃棄時エクスポート)が付属する。単一アカウント共有では未使用リソースも Free 枠(D1 は全 DB 合計 5GB 等)を圧迫する。
* D1 のバックアップは2層で持つ。
  * D1 Time Travel(Free プランで過去7日への復元)
  * GitHub Actions の `schedule` による日次 `wrangler d1 export` を R2 に保存。保持は短期(日次数世代)
* 定期実行は Cloudflare Cron ではなく Actions に置き、アカウントで共有する Cron 枠(5個)を消費しない。
* バックアップ保存先の R2 バケットは Terraform state 用バケットと分離し、権限も分ける。
* エクスポート内容を Actions のログや artifact に残さない。プラットフォームは格納データの機微性を判断できないため、常に残さない側に倒す。
* R2 / KV のバックアップは提供しない(リソース作成のみ)。

Time Travel の7日は「7日以内に異常へ気づく」ことを前提とする。利用頻度の低いプロダクトでは窓が閉じてから気づくため、日次エクスポートを第2の層として持つ。

## 可観測性

GitHub Actions の `schedule` で次を定期実行する。

* GraphQL Analytics API で Free 枠の消費率を取得し、閾値超過で GitHub Issue を起票する
* production への外形監視(疎通確認)を行い、失敗時に同様に Issue を起票する

Workers Logs(保持は最大7日)はダッシュボードで参照する。エラートラッキング SaaS の導入はプロダクトごとの判断とする。

Free プランは上限到達でサービスが停止するため、停止に気づく手段がなければ静かに壊れる。

## 廃棄手順

* 廃棄は `workflow_dispatch` でのみ実行する(destroy ガードにより通常パイプラインでは実行されない)。
* 手順: (1) `wrangler d1 export` で最終バックアップを R2 へ保存 → (2) `terraform destroy`。
* R2 に残るバックアップの残置/削除は `workflow_dispatch` の入力で明示的に選択する。プラットフォームは格納データの性質を知らないため、残置の可否を判断できない。

手順を文書ではなくワークフローとして持つ。D1 の削除は Time Travel ごと不可逆であり、実行時に手順書と実装が食い違っていると復旧できない。
