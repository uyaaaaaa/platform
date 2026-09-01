#!/bin/sh
# lib/ui/ の各機能に、機能どうしの隔離ルールが存在することを確認する。
#
# glob に後方参照が無いため機能の隔離は機能ごとに書く必要があり、書き忘れると
# 規約が黙って緩む。検査を置くことで、緩みが CI の失敗として現れるようにする。
set -eu

cd "$(dirname "$0")/.."

rules='import_rules.yaml'
status=0

for dir in lib/ui/*/; do
  feature=$(basename "$dir")
  [ "$feature" = 'core' ] && continue

  if ! grep -q "target: lib/ui/$feature/\*\*" "$rules"; then
    echo "check_import_rules: lib/ui/$feature の隔離ルールが $rules にありません。" >&2
    status=1
  fi
done

if [ "$status" -ne 0 ]; then
  echo "  既存の機能のブロックを複製し、機能名を置き換えてください。" >&2
fi

exit "$status"
