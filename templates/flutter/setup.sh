#!/bin/sh
# usage: sh setup.sh [<配置先>] [<Bundle ID の org>]
set -eu

here=$(cd "$(dirname "$0")" && pwd)
dest=${1:-app}
org=${2:-com.example}

if ! command -v flutter >/dev/null 2>&1; then
  echo "setup: flutter が PATH にありません。" >&2
  exit 1
fi

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
    # flutter create 直後は lib/main.dart のみが存在する。
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
