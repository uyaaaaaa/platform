import 'item.dart';

/// 保存の結果のうち、呼び出し側が必ず分岐すべきもの。
///
/// 通信断や 5xx のような予期しない失敗は例外として投げ、ここには現れない。
/// 予期する失敗を例外にすると、分岐の網羅を型が保証しなくなる。
sealed class ItemSaveOutcome {
  const ItemSaveOutcome();
}

final class ItemSaved extends ItemSaveOutcome {
  const ItemSaved(this.item);

  final Item item;
}

final class ItemRejected extends ItemSaveOutcome {
  const ItemRejected(this.fieldErrors);

  /// フィールド名 -> 表示するメッセージ。
  final Map<String, String> fieldErrors;
}

final class ItemConflicted extends ItemSaveOutcome {
  const ItemConflicted();
}
