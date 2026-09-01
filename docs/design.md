# プラットフォーム設計

## スコープ

本書は、個人開発プロダクト群が共通で利用するプラットフォーム(インフラ・CI/CD・運用)の構成を定義する。

定義するもの:

* リポジトリ構成と、共通部分の配布・更新の仕組み
* Cloudflare アカウントと環境のトポロジ
* IaC の分界と state 管理
* デプロイパイプラインとガードレール
* 権限とシークレットの供給経路
* ストレージのメニューと、バックアップ・廃棄の手順
* 可観測性
* ローカル開発とのインターフェース

定義しないもの(各プロダクトが決める):

* アプリケーション設計、フレームワーク、認証方式、データモデル
* クライアント実装(ネイティブ配布を含む)
* 利用者とテナンシーの意味論

## コスト方針

* 1プロダクトあたりのランニングコストは月 $3 以下とする。ドメイン代とストア配布費(Apple Developer Program 等)はプロダクト固有の初期投資として枠外に置く。
* Cloudflare は Workers Free プランで運用し、Free の上限(リクエスト 10万/日、CPU 10ms/呼び出し、Cron Triggers 5個/アカウント等)を設計制約として受け入れる。Free は上限到達でサービスが止まる代わりに請求が発生しない。リクエスト数に課金上限を設定できない Cloudflare の課金モデルにおいて、この「止まる」は予算超過を構造的に防ぐサーキットブレーカーとして機能する。
* Paid プラン前提の機能に依存した設計は行わない。Paid への移行(アカウント単位 $5/月)が設定変更のみで完了する状態を保つ。

## リポジトリ構成

リポジトリは3種に分かれる。

| 種別 | 内容 | 可視性 |
|---|---|---|
| `platform` | reusable workflows・Terraform modules・各領域のテンプレートの実体。`v1` タグを打つ対象 | public |
| `template-*` | プロダクトの骨。`platform` への参照と規約ファイルのみを含む template repository | public |
| プロダクト | 1プロダクト = 1リポジトリ。`template-*` から生成する | プロダクトごと |

共通部分はコピーではなく参照で配る。CI は reusable workflow(`uses: <owner>/platform/.github/workflows/<name>.yml@v1`)、IaC は Terraform module(`source = "git::...//templates/infra/modules/<name>?ref=v1"`)として参照する。コピー配布では基盤側の改善が既存プロダクトに届かず、配った瞬間から腐るためである。

platform の中では、テンプレートを技術領域ごとに `templates/<領域>/` へ分けて置き、利用時に実行するセットアップスクリプトを各領域の直下に `setup.sh` として置く。領域ごとに配布方法(参照かコピーか)も実行すべき手順も異なるため、領域を跨いだ共通の入口を1つ設けても分岐が増えるだけである。

reusable workflow だけはこの分類から外れ、`.github/workflows/` 直下に置く。GitHub が他リポジトリからの参照先をこの場所に限定しており、選択の余地がないためである。

`templates/<領域>/` と `template-*` は供給元と配布物の関係にある。`template-*` は GitHub の template repository 機能でプロダクトのリポジトリを生成するための骨であり、その中身のうちコピー配布するもの(git hooks、アプリ雛形)は `templates/` を正として取り込む。参照配布するもの(reusable workflow、Terraform module)は `template-*` には参照だけを置く。実体を2箇所で管理すると必ず食い違うため、`template-*` 側は常に platform から取り込んだ結果とし、そこで編集しない。

`v1` は移動タグとし、`platform` の main へのマージで CI が自動的に動かす。手動タグは単独開発では自己承認のセレモニーにしかならず、「マージ済みだが未リリース」という中間状態を生むためである。バージョン固定(semver)を採らないのは、利用者が単一である限り「全プロダクトが同時に壊れる」リスクより「更新が取り込まれず腐る」リスクのほうが大きいためである。

基盤側の変更は、マージ前に任意のプロダクトの PR から参照先を一時的にブランチ(`@<branch>`)へ向けて検証する。

`platform` を public にするのは、秘密を含まない(トークンは GitHub Secrets、state は R2 にある)ことに加え、private の reusable workflow を他リポジトリから参照するにはアクセス設定が必要になり、public なら確実に動くためである。

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

## ローカル開発

プラットフォームはコマンド名のみを規約化し、中身は各プロダクトが定義する。

| コマンド | 役割 |
|---|---|
| `npm run dev` | ローカル起動 |
| `npm run test` | テスト実行 |
| `npm run db:migrate` | マイグレーション適用 |
| `npm run db:seed` | 開発用データ投入 |

CI(reusable workflow)はプロダクトに対して「何を実行すればよいか」を知る必要があり、コマンド名はプラットフォームとプロダクトの間のインターフェースである。ツールチェーンのバージョン固定まで規定しないのは、ランタイム選択の自由(スコープ外)と矛盾するためである。

## 廃棄手順

* 廃棄は `workflow_dispatch` でのみ実行する(destroy ガードにより通常パイプラインでは実行されない)。
* 手順: (1) `wrangler d1 export` で最終バックアップを R2 へ保存 → (2) `terraform destroy`。D1 の削除は Time Travel ごと不可逆であり、また手順書は参照実装の更新から必ず乖離するため、動くコードとして保持する。
* R2 に残るバックアップの残置/削除は `workflow_dispatch` の入力で明示的に選択する。プラットフォームは格納データの性質を知らないため残置の可否を判断できず、判断は実行者が行う。

## リポジトリ規約(ガードレール)

* git hooks(Conventional Commits 検証、main への直接コミット/push 禁止、秘密情報らしき文字列の検出)は `templates/github/githooks/` を正とし、`template-*` 経由で各リポジトリにコピーする。クローンごとに github テンプレートの `setup.sh` を実行して `core.hooksPath` を向ける。
* hooks は参照配布できず伝播しないため、強制すべき検査は reusable workflow 側にも同等の実装を置く。hooks は早期検知の補助であり、CI を正とする。
* GitHub のリポジトリ設定と ruleset は `gh api` を用いたスクリプトを正とし、管理画面での直接編集は行わない。
