# flutter テンプレート

Flutter クライアントの雛形を置く。アーキテクチャの判断とその根拠は
[design.md](design.md) にある。

```
templates/flutter/
  setup.sh            # 利用時に実行する
  design.md           # アーキテクチャの判断
  app/                # 雛形の実体。プロダクトへコピーして使う
    analysis_options.yaml
    import_rules.yaml       # 依存方向のルール
    pubspec.yaml
    lib/
    test/
    tool/check_import_rules.sh
```

`app/` には1機能分の縦切り(`items` の一覧と編集)と認証が入っている。層をひととおり
通した実物であり、新しい機能はこれを複製して作る。

## 使い方

プロダクトのリポジトリの直下で実行する。

```sh
sh templates/flutter/setup.sh app com.example.myproduct
```

第1引数は配置先(既定は `app`)、第2引数は Bundle ID の org である。配置先が無ければ
`flutter create` で作り、雛形を展開して `flutter pub get` と生成まで済ませる。

何度実行しても同じ状態になる。規約ファイル(`analysis_options.yaml` /
`import_rules.yaml` / `tool/`)は platform を正として常に上書きし、`lib/` と `test/` は
既に中身があれば触らない。

Flutter パッケージ名は `app` に固定する。テストが `package:app/...` で参照するため、
ここが揺れると配置先ごとに import を書き換えることになる。

## 検査

```sh
cd app
sh tool/check_import_rules.sh
dart analyze --fatal-infos
flutter test
```

**`flutter analyze` は使わない。** analyzer plugin を読み込まないため、依存方向の
違反を1件も報告しない。`dart analyze` は plugin の診断に加えて `flutter analyze` が
出すものをすべて出す。

## CI

プロダクト側から reusable workflow を呼ぶ。`app/` の変更だけを対象にする。

```yaml
on:
  pull_request:
    paths:
      - 'app/**'
      - '.github/workflows/app.yml'

jobs:
  app:
    uses: uyaaaaaa/platform/.github/workflows/flutter-ci.yml@v1
    with:
      build-android: true
      build-ios: false
```

`build-ios` の既定が `false` なのは、macOS runner が private リポジトリでは実行時間を
10倍係数で消費するためである。public リポジトリでは標準 runner が無料であり、その場合は
`true` にしてよい。可視性はプロダクトごとの判断とする。

## 規約

* 依存方向(`ui → data/repositories → data/services`、`ui, data → domain/models`)は
  `import_rules.yaml` を正とし、`dart analyze` が `error` として落とす。
* 機能どうしの隔離ルールは機能ごとに書く。glob に後方参照が無く一般化できないためで、
  書き忘れは `tool/check_import_rules.sh` が検出する。
* 生成物(`*.g.dart`)はコミットする。CI が生成し直し、差分があれば落とす。
* `app/` のコマンドは `flutter` を正とする。`docs/design.md` の `npm run` 規約は
  Node ランタイムのプロダクトを対象としており、薄い npm スクリプトで包み直さない。
