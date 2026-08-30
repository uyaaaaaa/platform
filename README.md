# platform

個人開発プロダクト群が共通利用する基盤。GitHub Actions の reusable workflows と Terraform modules を提供し、各プロダクトのリポジトリは `@v1` タグでこれらを参照する。

設計は [docs/design.md](docs/design.md) に定義する。

## v1 タグ

`v1` は移動タグであり、main への push で CI([move-v1-tag](.github/workflows/move-v1-tag.yml))が HEAD へ自動追従させる。手動でタグを打たない。

## 基盤変更の事前検証

マージ前の基盤変更は、任意のプロダクトの PR から参照先を一時的にブランチへ向けて検証する。

- reusable workflow: `uses: uyaaaaaa/platform/.github/workflows/<name>.yml@<branch>`
- Terraform module: `source = "git::https://github.com/uyaaaaaa/platform.git//modules/<name>?ref=<branch>"`

検証が済んだら参照を `@v1` / `?ref=v1` に戻し、platform 側のブランチを main へマージする。
