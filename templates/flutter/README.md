# flutter テンプレート

## スコープ

本書は Flutter クライアント雛形の構成と、配置・検査の手順を定義する。

以下は定義しない。

* アーキテクチャ
* プロダクト固有のドメイン設計とデータモデル

## 構成

```
templates/flutter/
  setup.sh            # 利用時に実行する
  design.md
  app/                # 雛形の実体
    analysis_options.yaml
    import_rules.yaml       # 依存方向のルール
    pubspec.yaml
    lib/
    test/
    tool/check_import_rules.sh
```

`app/` には1機能分の縦切り(`items` の一覧と編集)と認証が入っている。新しい機能はこれを複製して作る。

## 使い方

プロダクトのリポジトリの直下で実行する。

```sh
sh templates/flutter/setup.sh app com.example.myproduct
```

第1引数は配置先(既定は `app`)、第2引数は Bundle ID の org である。配置先が無ければ `flutter create` で作り、雛形を展開して `flutter pub get` と生成まで行う。

何度実行しても同じ状態になる。`analysis_options.yaml`・`import_rules.yaml`・`tool/` は毎回上書きし、`lib/` と `test/` は既に中身があれば触らない。

Flutter パッケージ名は `app` に固定する。

## 検査

```sh
cd app
sh tool/check_import_rules.sh
dart analyze --fatal-infos
flutter test
```

`flutter analyze` は使わない。analyzer plugin を読み込まず、依存方向の違反を1件も報告しない。

## CI

プロダクト側から reusable workflow を呼び、`app/` の変更を対象にする。

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

`build-ios` の既定は `false` である。macOS runner は private リポジトリでは実行時間を10倍係数で消費する。public リポジトリでは標準 runner が無料であり、その場合は `true` にしてよい。
