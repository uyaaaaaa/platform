# infra 設計

Cloudflare 上のインフラと、その運用に関する判断を定義する。リポジトリ構成・共通部分の配布・コスト方針といった領域を跨ぐ判断は [docs/design.md](../../docs/design.md) にある。

## Cloudflare アカウントと環境

* 全プロダクトで単一の Cloudflare アカウントを共有する。1つのドメインのサブドメインをプロダクトへ割り当てる運用は、zone がアカウントに帰属する以上単一アカウントでしか成立しない(サブドメインを独立 zone として分離する subdomain setup は Enterprise 限定)。Paid 移行時に $5/月 を全プロダクトで按分できる利点もある。
* アカウント ID は Terraform module の変数とし、プロダクト単位で別アカウントへ切り出せる形を保つ。Free の上限(特に Cron Triggers 5個)はアカウント単位で共有されるため、枠を枯渇させたプロダクトの退避経路を残す。
* 環境は production / preview の2つ。リソース命名は `<product>-<env>` で統一し、名前は Terraform が生成する。preview の主目的は D1 マイグレーションのリハーサルである。スキーマ変更の失敗はコードと違いロールバックできないため、本番適用前に試す場所を常設する。
* wrangler の環境サフィックスなしのルート Worker は作らない。デプロイは常に `--env` を指定し、CI で強制する。
* Preview URL は preview 環境の Worker でのみ有効化する。Preview URL は対象バージョンが宣言する bindings で動くため、production の Worker に発行すると本番データに接続する。

## IaC の分界

| 管轄 | 対象 |
|---|---|
| Terraform | 消えると復旧できない長寿命リソース: zone / DNS / D1 / R2 / KV / API トークン / アカウント設定 |
| wrangler | 置き換え可能なもの: Worker のコード、bindings、ランタイムシークレット |

変更頻度が桁違い(デプロイは PR ごと、インフラ変更は月数回)のものを同一 state に載せると、state ロックがデプロイのボトルネックになる。また Workers の versions / deployments による段階ロールアウトと即時ロールバックは wrangler 経由でのみ活きる。

* wrangler の automatic provisioning は使用しない。Terraform を正とする分界を静かに壊すためである。
* Terraform state は R2 の S3 互換 backend に置く。外部依存を増やさず Cloudflare 内で完結する。state には API トークン等の秘密が平文で入るため、リポジトリには置かない。state 用バケットは非公開とし、専用トークンのみがアクセスできる。
* 手動で作成するのは state 用 R2 バケット1つとブートストラップ用 API トークン1つのみ。以降のリソースとトークンはすべて Terraform が作成する。

## CI/CD

* CI/CD は GitHub Actions に一本化する。lint / test / Terraform / wrangler deploy をすべて Actions で実行する。Terraform の実行環境として Actions は必須であり、デプロイ経路を複線化すると「どちらの経路で反映されたか」が常に問題になる。
* main へのマージで production まで全自動でデプロイする。単独開発における承認ステップは自己承認のセレモニーであり安全性に寄与しない。またデプロイされていない main を抱えると、本番に何が出ているかが追えなくなる。
* ガードは人間の承認ではなく機械検査として置く:
  * `terraform plan` の結果に destroy または replace が含まれる場合、CI を失敗させる。実行するには明示フラグ付きの手動実行(`workflow_dispatch`)を用いる。
  * production への D1 マイグレーション適用の直前に、`wrangler d1 export` で現状を R2 へ退避してから適用する。破壊的 SQL の静的検査は網羅できず、不完全なガードは「CI が通ったから安全」という誤った信頼を生む。検出ではなく復旧可能性で守る。
* production へのデプロイ順序: (1) マイグレーションがある場合は export で退避 → (2) `wrangler d1 migrations apply` → (3) `wrangler deploy`。
* コードのロールバックは wrangler の versions 機能で行う。

## 権限とシークレット

Cloudflare API トークンは2本に分ける。

| トークン | 権限 | 利用箇所 |
|---|---|---|
| Terraform 用 | 広い(リソース・トークン発行を含む) | infra ワークフロー専用。GitHub Environment で参照元を限定する |
| デプロイ用 | Workers 系 + D1 編集 + Analytics Read | 通常のアプリワークフロー |

分割の目的は、日常的に動くワークフローが持つ権限を小さく保つことにある。infra 変更は稀であり、隔離のコストは低い。

アプリのランタイムシークレットは GitHub Secrets(環境ごと)を正とし、デプロイ時に CI が `wrangler secret put` で Cloudflare へ同期する。同期対象は命名規約(プレフィックス)で機械判定する。手動投入では設定済みシークレットの記録がどこにも残らず、再構築時に何を投入すべきか再現できない。値そのものは記録できなくても、キーの一覧と供給経路は再現可能に保つ。

## ストレージとバックアップ

* Terraform module のリソースはオプトインとする(`enable_d1` / `enable_r2` / `enable_kv` / `enable_static_assets`)。有効化したリソースにのみ、対応する運用(バックアップ、廃棄時エクスポート)が付属する。単一アカウント共有では未使用リソースも Free 枠(D1 は全 DB 合計 5GB 等)を圧迫するため、リソースの選択はプロダクトに委ね、選んだ結果の運用をプラットフォームが引き受ける。
* D1 のバックアップは2層で持つ:
  * D1 Time Travel(Free プランで過去7日への復元)
  * GitHub Actions の `schedule` による日次 `wrangler d1 export` を R2 に保存。保持は短期(日次数世代)
  * 7日の復元窓は「7日以内に異常へ気づく」ことが前提であり、利用頻度の低いプロダクトでは窓が閉じてから気づくため、自前の層を足す。定期実行を Cloudflare Cron ではなく Actions に置くのは、アカウント共有の Cron 枠(5個)を消費しないためである。
* バックアップ保存先の R2 バケットは Terraform state 用バケットと分離し、権限も分ける。
* エクスポート内容を Actions のログや artifact に残さない。プラットフォームは格納データの機微性を判断できないため、常に残さない側に倒す。
* R2 / KV のバックアップは提供しない(リソース作成のみ)。

## 可観測性

GitHub Actions の `schedule` で次を定期実行する:

* GraphQL Analytics API で Free 枠の消費率を取得し、閾値超過で GitHub Issue を起票する
* production への外形監視(疎通確認)を行い、失敗時に同様に Issue を起票する

Free プランは上限到達でサービスが停止するため、停止に気づく手段がなければ静かに壊れる。通知先を GitHub Issue にするのは、既存の仕組みだけで履歴と対応記録が残り、外部依存が増えないためである。

Workers Logs(Free: 20万イベント/日、保持3日)はダッシュボードで参照する。エラートラッキング SaaS の導入はプロダクトごとの判断とする。

## 廃棄手順

* 廃棄は `workflow_dispatch` でのみ実行する(destroy ガードにより通常パイプラインでは実行されない)。
* 手順: (1) `wrangler d1 export` で最終バックアップを R2 へ保存 → (2) `terraform destroy`。D1 の削除は Time Travel ごと不可逆であり、また手順書は参照実装の更新から必ず乖離するため、動くコードとして保持する。
* R2 に残るバックアップの残置/削除は `workflow_dispatch` の入力で明示的に選択する。プラットフォームは格納データの性質を知らないため残置の可否を判断できず、判断は実行者が行う。
