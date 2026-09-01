# infra テンプレート

Cloudflare 上のインフラと、そこへ載せるための実体を置く。トポロジと運用に関する
判断は [design.md](design.md) にある。

```
templates/infra/
  modules/<name>/    # プロダクトから参照される module
```

## Terraform modules

プロダクト側からは参照で使う。

```hcl
source = "git::https://github.com/uyaaaaaa/platform.git//templates/infra/modules/<name>?ref=v1"
```

コピー配布ではないため、他のテンプレートと違い `setup.sh` を持たない。プロダクト側で
実行すべきものが無く、参照先を書くだけで済むためである。ただし `docs/design.md` が
手動作業として残している state 用 R2 バケットとブートストラップ用 API トークンの作成は、
将来ここにスクリプトとして置く余地がある。

module はまだ無い。

## reusable workflow

実体は [`.github/workflows/`](../../.github/workflows/) 直下にある。GitHub が他リポジトリ
からの参照先をその場所に限定しているためであり、置き場所が強制されているだけで、中身は
この領域に属する。使い方はここに書く。

### worker-cicd

Cloudflare Workers プロダクトのアプリ CI/CD。PR で test → preview、main へのマージで
production まで自動で進む。プロダクト側はこれを呼ぶだけでよい。

```yaml
name: cicd
on:
  pull_request:
  push:
    branches: [main]

jobs:
  cicd:
    uses: uyaaaaaa/platform/.github/workflows/worker-cicd.yml@v1
    with:
      enable-d1: true
      backup-bucket: <バックアップ用 R2 バケット名>
    secrets: inherit
```

`secrets: inherit` は必須である。Cloudflare へ同期するシークレットをプレフィックスで
機械判定するため、workflow 側で受け取るシークレットを列挙できない。

| 入力 | 既定 | 意味 |
|---|---|---|
| `working-directory` | `.` | Worker のパッケージの位置。モノレポでは `worker` |
| `node-version` | `22` | Node のバージョン。プロダクトが上書きしてよい |
| `enable-d1` | `false` | module の `enable_d1` と揃える。マイグレーションと退避が付く |
| `d1-binding` | `DB` | wrangler 設定での D1 の binding 名 |
| `migrations-dir` | `migrations` | マイグレーションの位置(`working-directory` からの相対) |
| `backup-bucket` | (なし) | 適用前エクスポートの保存先 R2 バケット。`enable-d1` のとき必須 |
| `secret-prefix` | `APP_SECRET_` | Cloudflare へ同期する GitHub Secrets のプレフィックス |
| `wrangler-version` | `4` | プロダクトが wrangler を依存に持たない場合に使うバージョン |

| シークレット | 要否 | 用途 |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | 必須 | デプロイ用トークン |
| `CLOUDFLARE_ACCOUNT_ID` | 必須 | 対象アカウント |
| `CLOUDFLARE_BACKUP_API_TOKEN` | 任意 | バックアップ用バケットに限定したトークン。無ければデプロイ用で代替する |
| `<secret-prefix>*` | 任意 | Cloudflare へ同期するランタイムシークレット。同期時にプレフィックスを外す(`APP_SECRET_STRIPE_KEY` → `STRIPE_KEY`) |

プロダクト側に要求するもの:

* `npm run test` が定義されていること(コマンド名規約は
  [docs/design.md](../../docs/design.md) ローカル開発)
* wrangler 設定に `env.preview` と `env.production` があること。`--dry-run` で両方を
  検査する
* GitHub Environment `preview` / `production`。環境ごとのシークレットはここに置く

環境名は入力にしていない。環境は production / preview の2つと決まっており
([design.md](design.md))、名前を可変にすると設計とプロダクトが静かにずれる。

`guard` job は git hooks と同等の検査を行う。hooks は参照配布できず `--no-verify` で
迂回もできるため、強制すべきものは CI を正とする。

* PR タイトルが Conventional Commits であること(squash merge により main の件名に
  なるのは PR タイトルである)
* 秘密情報らしき文字列・`.env` が追加されていないこと
* `--env` を伴わない `wrangler deploy` が書かれていないこと
