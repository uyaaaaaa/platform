import 'item.dart';

sealed class ItemSaveOutcome {
  const ItemSaveOutcome();
}

final class ItemSaved extends ItemSaveOutcome {
  const ItemSaved(this.item);

  final Item item;
}

final class ItemRejected extends ItemSaveOutcome {
  const ItemRejected(this.fieldErrors);

  final Map<String, String> fieldErrors;
}

final class ItemConflicted extends ItemSaveOutcome {
  const ItemConflicted();
}
