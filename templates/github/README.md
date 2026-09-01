# github テンプレート

GitHub のリポジトリ設定・ruleset・git hooks を置く。

```
templates/github/
  setup.sh            # 利用時に実行する
  ruleset-main.json   # main ブランチの ruleset 定義
  githooks/           # commit-msg / pre-commit / pre-push
```

## 使い方

対象のリポジトリで実行する。

```sh
sh templates/github/setup.sh
```

`core.hooksPath` を `githooks/` へ向け、リポジトリ設定と ruleset を適用する。参照はすべて
スクリプト自身からの相対で解決するため、テンプレートをコピーした先でも動く。何度実行しても
同じ状態になる。

## 規約

* git hooks(Conventional Commits 検証、main への直接コミット/push 禁止、秘密情報らしき文字列の検出)は `githooks/` を正とし、`template-*` 経由で各リポジトリにコピーする。クローンごとに `setup.sh` を実行して `core.hooksPath` を向ける。
* hooks は参照配布できず伝播しないため、強制すべき検査は reusable workflow 側にも同等の実装を置く。hooks は早期検知の補助であり、CI を正とする。
* GitHub のリポジトリ設定と ruleset は `gh api` を用いたスクリプトを正とし、管理画面での直接編集は行わない。
