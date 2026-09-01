# platform

個人開発プロダクト群が共通利用する基盤。GitHub Actions の reusable workflows と Terraform modules を提供し、各プロダクトのリポジトリは `@v1` タグでこれらを参照する。

領域を跨ぐ設計は [docs/design.md](docs/design.md) に、領域固有の設計は各テンプレート配下に定義する。

## ディレクトリ構成

テンプレートは技術領域ごとに `templates/<領域>/` へ置く。利用する際に実行するセットアップスクリプトは、各領域の直下に `setup.sh` として置く。

```
templates/
  github/     # リポジトリ設定・ruleset・git hooks
  infra/      # Terraform modules
  flutter/    # Flutter クライアント雛形
.github/
  workflows/  # reusable workflows と本リポジトリ自身の CI
```

reusable workflow だけは領域別にせず `.github/workflows/` 直下に置く。GitHub が他リポジトリからの参照先をこの場所に限定しているためである。

## セットアップ

クローン後に実行する。

```sh
sh templates/github/setup.sh
```

git hooks の有効化(`core.hooksPath`)、リポジトリ設定、ruleset の適用を行う。何度実行しても同じ状態になる。

## reusable workflow

### worker-cicd

Cloudflare Workers プロダクトのアプリ CI/CD。PR で test → preview、main へのマージで production まで自動で進む。プロダクト側はこれを呼ぶだけでよい。

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

`secrets: inherit` は必須である。Cloudflare へ同期するシークレットをプレフィックスで機械判定するため、workflow 側で受け取るシークレットを列挙できない。

| 入力 | 既定 | 意味 |
|---|---|---|
| `working-directory` | `.` | Worker のパッケージの位置。モノレポでは `worker` |
| `node-version` | `22` | Node のバージョン。プロダクトが上書きしてよい |
| `enable-d1` | `false` | Terraform module の `enable_d1` と揃える。マイグレーションと退避が付く |
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

* `npm run test` が定義されていること(コマンド名規約は [docs/design.md](docs/design.md) ローカル開発)
* wrangler 設定に `env.preview` と `env.production` があること。`--dry-run` で両方を検査する
* GitHub Environment `preview` / `production`。環境ごとのシークレットはここに置く

環境名は入力にしていない。環境は production / preview の2つと決まっており([templates/infra/design.md](templates/infra/design.md))、名前を可変にすると設計とプロダクトが静かにずれる。

`guard` job は git hooks と同等の検査を行う。hooks は参照配布できず `--no-verify` で迂回もできるため、強制すべきものは CI を正とする。

* PR タイトルが Conventional Commits であること(squash merge により main の件名になるのは PR タイトルである)
* 秘密情報らしき文字列・`.env` が追加されていないこと
* `--env` を伴わない `wrangler deploy` が書かれていないこと

## v1 タグ

`v1` は移動タグであり、main への push で CI([move-v1-tag](.github/workflows/move-v1-tag.yml))が HEAD へ自動追従させる。手動でタグを打たない。

## 基盤変更の事前検証

マージ前の基盤変更は、任意のプロダクトの PR から参照先を一時的にブランチへ向けて検証する。

- reusable workflow: `uses: uyaaaaaa/platform/.github/workflows/<name>.yml@<branch>`
- Terraform module: `source = "git::https://github.com/uyaaaaaa/platform.git//templates/infra/modules/<name>?ref=<branch>"`

検証が済んだら参照を `@v1` / `?ref=v1` に戻し、platform 側のブランチを main へマージする。
