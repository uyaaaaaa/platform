#!/bin/sh
# Flutter クライアントの雛形を配置する。
#
# 使い方:
#   sh templates/flutter/setup.sh [<配置先>] [<Bundle ID の org>]
#
# 既定の配置先は app/ である。モノレポでは app/(Flutter)と worker/
# (Cloudflare Workers)が同居する。
#
# 何度実行しても同じ状態になる:
#   * 規約ファイル(analysis_options.yaml / import_rules.yaml / tool/)は
#     常に上書きする。platform を正とするためである。
#   * 雛形(lib/ / test/ / pubspec.yaml)は既に在れば触らない。
#     プロダクト側で育てたコードを消さないためである。
set -eu

here=$(cd "$(dirname "$0")" && pwd)
dest=${1:-app}
org=${2:-com.example}

if ! command -v flutter >/dev/null 2>&1; then
  echo "setup: flutter が PATH にありません。" >&2
  exit 1
fi

# パッケージ名は app に固定する。テストが package:app/... で参照するため、
# ここが揺れると配置先ごとに import を書き換えることになる。
if [ ! -d "$dest" ]; then
  echo "setup: $dest を作成します (org=$org)"
  flutter create --platforms=android,ios --project-name app --org "$org" "$dest"
  rm -f "$dest/test/widget_test.dart"
fi

echo "setup: 規約ファイルを適用します"
cp "$here/app/analysis_options.yaml" "$dest/analysis_options.yaml"
cp "$here/app/import_rules.yaml" "$dest/import_rules.yaml"
mkdir -p "$dest/tool"
cp "$here/app/tool/check_import_rules.sh" "$dest/tool/check_import_rules.sh"
chmod +x "$dest/tool/check_import_rules.sh"

for dir in lib test; do
  if [ -n "$(ls -A "$dest/$dir" 2>/dev/null)" ]; then
    # flutter create 直後の lib/main.dart だけの状態は雛形で置き換えてよい。
    if [ "$dir" = 'lib' ] && [ "$(find "$dest/lib" -type f | wc -l)" -eq 1 ]; then
      rm -rf "$dest/lib"
    else
      echo "setup: $dest/$dir は既にあるため触りません"
      continue
    fi
  fi
  # 配置先が空で存在する場合があるため、ディレクトリごとではなく中身を写す。
  mkdir -p "$dest/$dir"
  cp -R "$here/app/$dir/." "$dest/$dir/"
done

if [ ! -f "$dest/pubspec.yaml" ] || ! grep -q 'flutter_riverpod' "$dest/pubspec.yaml"; then
  cp "$here/app/pubspec.yaml" "$dest/pubspec.yaml"
fi

echo "setup: 依存を解決します"
(cd "$dest" && flutter pub get && dart run build_runner build)

echo "setup: 完了しました。検査は次で行います。"
echo "  cd $dest && sh tool/check_import_rules.sh && dart analyze --fatal-infos && flutter test"
