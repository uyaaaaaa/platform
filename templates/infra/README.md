# infra テンプレート

## スコープ

本書は、Cloudflare 向けに提供する Terraform module と reusable workflow の使い方を定義する。

Cloudflare 上のトポロジと運用に関する判断は定義しない。

```
templates/infra/
  modules/<name>/    # プロダクトから参照される module
```

## Terraform modules

プロダクト側からは参照で使う。参照で配るため `setup.sh` を持たない。

```hcl
source = "git::https://github.com/uyaaaaaa/platform.git//templates/infra/modules/<name>?ref=v1"
```

## reusable workflow

実体は [`.github/workflows/`](../../.github/workflows/) 直下にある。GitHub が他リポジトリ
からの参照先をこの場所に限定している。

### worker-cicd

Cloudflare Workers プロダクトのアプリ CI/CD。PR で test → preview、main へのマージで
production まで自動で進む。

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

`secrets: inherit` は必須である。

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

* `npm run test` が定義されていること
* wrangler 設定に `env.preview` と `env.production` があること。`--dry-run` で両方を
  検査する
* GitHub Environment `preview` / `production`。環境ごとのシークレットはここに置く

環境名は入力に取らない。

`guard` job は次を検査する。

* PR タイトルが Conventional Commits であること
* 秘密情報らしき文字列・`.env` が追加されていないこと
* `--env` を伴わない `wrangler deploy` が書かれていないこと
