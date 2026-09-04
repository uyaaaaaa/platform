# flutter 設計

## スコープ

本書は Flutter クライアントの標準アーキテクチャを定義する。対象は iOS / Android 向けの、サーバーのデータを表示・編集することを主とする認証付きアプリであり、バックエンドは Cloudflare Workers + D1 である。

以下は定義しない。

* Web・デスクトップ向けの構成
* プロダクト固有のドメイン設計とデータモデル
* ストアへの配布(申請・審査・証明書の運用)

## 骨格

```
app/lib/
  main.dart
  config/              # 環境設定と DI の組み立て
  routing/             # go_router
  ui/
    core/              # 全機能が共有する UI(themes / widgets)
    <feature>/
      view_models/     # 画面ごとの状態
      widgets/         # 画面とその部品
  domain/models/       # ドメインモデル。機能横断で共有する
  data/
    repositories/      # 真実の源。キャッシュ・エラー処理・DTO 変換
    services/          # HTTP クライアントとローカルストア。状態を持たない
```

UI 層は機能ごとに、data / domain 層は種別ごとに分ける。層は UI と data の2つとし、UseCase 層は置かない。

## UI 層

View と ViewModel は1対1とする。View は自分の ViewModel 以外の ViewModel を参照しない。表示に必要なデータは、他の画面の状態からではなく Repository から取得する。

View に置いてよいロジックは次に限る。

* ViewModel のフラグや null 判定による表示の出し分け
* アニメーション
* 画面サイズ・向きに応じたレイアウト
* 単純な遷移

それ以外の状態はすべて ViewModel が持つ。`TextEditingController` のような入力の一時的な保持は View に置いてよいが、その値を使う判断は ViewModel に渡す。

## data 層

* Repository はアプリケーションデータの真実の源とし、扱うデータの種別ごとに1つ置く。キャッシュ・エラー処理・再取得・セッション状態を持つ。
* **Repository は互いを参照しない。** 複数の Repository のデータを必要とする処理は ViewModel に置く。
* Service は外部との境界ごとに1つ置き、状態を持たない。

## 依存方向

```
ui → data/repositories → data/services
ui, data → domain/models
```

* `data` から `ui`・`routing`・`config` への import を禁止する。
* `ui/<feature>` 間の直接 import を禁止する。共有するものは `ui/core` へ上げる。
* `ui/core` から `ui/<feature>` への import を禁止する。
* `ui` から `data/services` への直接 import を禁止する。触れてよいのは `data/repositories` までとする。
* `data/services` から `data/repositories` への import を禁止する。
* `domain/models` は他のいずれの層にも Flutter にも依存しない。

### 強制

ルールは `import_rules.yaml` に宣言し、analyzer plugin `import_rules` が解析時に検査する。違反の severity は `error` とする。

検査は `dart analyze --fatal-infos` で行う。**`flutter analyze` は使わない。** `flutter analyze` は analyzer plugin を読み込まず、依存方向の違反を1件も報告しない。`dart analyze` は plugin の診断に加えて `flutter analyze` が出すものをすべて出す。severity を既定の `info` にすると `dart analyze` の終了コードが 0 のままになる。

### 機能どうしの隔離

`lib/ui/<feature>/` の相互依存の禁止は、機能ごとに1ブロックずつ `import_rules.yaml` に書く。`tool/check_import_rules.sh` が `lib/ui/` 配下の各機能に対応するルールの存在を検査し、CI で実行する。

glob に後方参照が無いため、「対象ファイルが属する機能」を1つの式では表現できない(`$TARGET_DIR` は対象ファイルの親ディレクトリを指し、`lib/ui/<feature>/<種別>/` の2階層構成では機能の境界に届かない)。ブロックを書き忘れると、その機能の隔離だけが何の表示もなく失われる。

## 状態管理

Riverpod を使う。DI・状態通知・非同期状態・破棄をこれ1つで扱い、`provider` や `ChangeNotifier` と併用しない。

コード生成は使わない。`json_serializable` のために build_runner は導入するが、生成対象はモデルに限る。

**自動再試行は無効にする。** `ProviderScope` に再試行しない方針を渡し、再試行は利用者の明示的な操作としてのみ行う。Riverpod 3 は失敗した provider を既定で最大10回、200ms から 6.4s の指数バックオフで再試行する。1画面の通信失敗が最大11回のリクエストになり、Workers Free の 10万リクエスト/日 を圧迫する。

## モデル

* モデルは immutable とする。
* DTO とドメインモデルは同一のものを使う。API が返す形と画面が必要とする形が食い違う機能でのみ、その機能で分ける。
* 詰め替えは最大2段(DTO → ドメインモデル)までとする。UI 用の3つ目の形は、画面が別形状を必要とする場合にその画面の `view_models/` 内にのみ置く。
* シリアライズは `json_serializable` で行う。
* 生成物(`*.g.dart`)はコミットする。
* モデル数が20を超えたら `freezed` を導入する。それまでは `copyWith` と等価性を手で書く。

## エラー

失敗を3つに分ける。

| 種別 | 表現 | 扱う場所 |
|---|---|---|
| 予期しない失敗(通信断・5xx・パース失敗) | 例外を投げる | ViewModel が `AsyncValue` として受け、`ui/core` の共通表示に載せる |
| 予期する業務失敗(バリデーション・競合・権限) | `domain/models` の sealed 型で返す | 画面ごとに分岐して表示する |
| プログラミングエラー | `assert` / 例外 | 実行時に扱わない |

汎用の `Result` 型と `Command` パターンは置かない。失敗・スタックトレース・実行中の状態は `AsyncValue` と `AsyncNotifier` が持つ。

予期しない失敗の表示は、原因を出さず一律の文言と再試行のみとする。これにより UI 層が data 層の例外型を知らずに済む。

## キャッシュ

API レスポンスをエンドポイント単位でそのまま保存し、保存済みを先に流してから取得し直した結果を流す。ローカル DB にリレーショナルなミラーは持たない。書き込みはオンラインを必須とし、送信キューと楽観的更新を持たない。

* 保管先は `sqflite` の単一テーブル(`key` / `body` / `fetched_at` / `user_id`)とする。
* 失効はエンドポイント単位に Repository が TTL を宣言する。
* 認証ユーザーが切り替わったときは `user_id` を鍵に一括破棄する。
* キャッシュは Repository の内部に閉じる。ViewModel はキャッシュの存在を知らない。
* HTTP クライアントの interceptor によるキャッシュは使わない。
* 編集対象の単体取得はキャッシュを経由しない。編集は常にサーバーの現在値から始める。

Workers Free はリクエスト 10万/日 が上限であり、モバイルアプリは起動のたびに API を叩く。閲覧キャッシュはこの上限に対する要求数の抑制を兼ねる。

## 認証

* トークンは `flutter_secure_storage` に保管する。
* 401 を受けたリフレッシュと元のリクエストの再送は Service が行う。
* 認証状態の真実の源は `AuthRepository` とする。`go_router` の redirect はこの状態のみを見る。Service はトークンを扱うが状態を持たない。
* サインアウトはトークンの破棄とそのユーザーのキャッシュの破棄をあわせて行う。

## 置かないもの

* **UseCase / Domain 層。** 「複数の Repository のデータを結合する」「極端に複雑」「複数の ViewModel で再利用する」のいずれかに当たる処理が現れた時点で、その処理にだけ導入する。
* **差し替え予定のない `abstract class`。** 抽象は3条件テスト(揮発性がある / 実装が2つ以上ある / テストで実物が使えない)に合格したものだけに置く。合格するのは Repository と Service である。
* **Aggregate / トランザクション境界 / Application Service 層。** クライアントには原子性も真実の源も無く、置くとサーバー責務の二重実装になる。
* **`isar` / `hive`。**

## テスト

* Service・Repository・ViewModel には unit テストを書く。View には widget テストを書き、ルーティングと DI の結線を対象に含める。
* テストダブルは fake を作る。`mocktail` は fake を書くのが過剰な場面に限る。
* integration テストは重要なユースケースを覆うのに十分なだけ書く。網羅は unit / widget 側で取る。
* golden テストは `ui/core` のコンポーネントに限定し、CI は Linux に固定する。

## ローカル開発と CI

`app/` 配下のコマンドは `flutter` を正とする。

モノレポでは `paths` で変更を検知し、`app/` と `worker/` の job を分ける。`app/` の検査は次の4つであり、reusable workflow `flutter-ci.yml` が実行する。

1. `dart run build_runner build` の後に `git diff --exit-code`
2. `sh tool/check_import_rules.sh`
3. `dart analyze --fatal-infos`
4. `flutter test`

iOS ビルドの実行可否は workflow の入力で切り替え、既定を「実行しない」とする。macOS runner は private リポジトリでは実行時間を10倍係数で消費する。

runner のラベルと JDK のバージョンも workflow の入力とする。既定は `ubuntu-latest` / `macos-latest` / `17` である。

* Android ビルドの JDK は runner image の既定に任せず、入力の値を `actions/setup-java` で用意する。`flutter create` が生成する Android プロジェクトは Java 17 を要求する。
* runner のラベルを入力にしておくのは、`-latest` の指す image が移行したときにプロダクト側で固定して退避できるようにするためである。platform は移動タグで配るため、固定できないと移行の影響を全プロダクトが同時に受ける。
