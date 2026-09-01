# platform

個人開発プロダクト群が共通利用する基盤。GitHub Actions の reusable workflows と Terraform modules を提供し、各プロダクトのリポジトリは `@v1` タグでこれらを参照する。

領域を跨ぐ設計は [docs/design.md](docs/design.md) に、領域固有の設計は各テンプレート配下に定義する。

## ディレクトリ構成

テンプレートは技術領域ごとに `templates/<領域>/` へ置く。利用する際に実行するセットアップスクリプトは、各領域の直下に `setup.sh` として置く。

```
templates/
  github/     # リポジトリ設定・ruleset・git hooks
  infra/      # Cloudflare(Terraform modules・デプロイ)
  flutter/    # Flutter クライアント雛形
.github/
  workflows/  # reusable workflows と本リポジトリ自身の CI
```

reusable workflow だけは領域別にせず `.github/workflows/` 直下に置く。GitHub が他リポジトリからの参照先をこの場所に限定しているためである。ただし置き場所が強制されるだけであって、中身は領域に属する。使い方と入力の定義は対応する領域のテンプレート配下に書く。

| reusable workflow | 領域 | 使い方 |
|---|---|---|
| `worker-cicd.yml` | infra(Cloudflare Workers) | [templates/infra/README.md](templates/infra/README.md) |

## セットアップ

クローン後に実行する。

```sh
sh templates/github/setup.sh
```

git hooks の有効化(`core.hooksPath`)、リポジトリ設定、ruleset の適用を行う。何度実行しても同じ状態になる。

## v1 タグ

`v1` は移動タグであり、main への push で CI([move-v1-tag](.github/workflows/move-v1-tag.yml))が HEAD へ自動追従させる。手動でタグを打たない。

## 基盤変更の事前検証

マージ前の基盤変更は、任意のプロダクトの PR から参照先を一時的にブランチへ向けて検証する。

- reusable workflow: `uses: uyaaaaaa/platform/.github/workflows/<name>.yml@<branch>`
- Terraform module: `source = "git::https://github.com/uyaaaaaa/platform.git//templates/infra/modules/<name>?ref=<branch>"`

検証が済んだら参照を `@v1` / `?ref=v1` に戻し、platform 側のブランチを main へマージする。
