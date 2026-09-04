import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/dependencies.dart';
import '../../../domain/models/item.dart';
import '../../../domain/models/item_save_outcome.dart';

class ItemEditorState {
  const ItemEditorState({
    this.saving = false,
    this.fieldErrors = const {},
    this.conflicted = false,
    this.saved = false,
  });

  final bool saving;
  final Map<String, String> fieldErrors;
  final bool conflicted;
  final bool saved;

  ItemEditorState copyWith({
    bool? saving,
    Map<String, String>? fieldErrors,
    bool? conflicted,
    bool? saved,
  }) => ItemEditorState(
    saving: saving ?? this.saving,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    conflicted: conflicted ?? this.conflicted,
    saved: saved ?? this.saved,
  );
}

class ItemEditorViewModel extends Notifier<ItemEditorState> {
  @override
  ItemEditorState build() => const ItemEditorState();

  Future<void> save(Item item) async {
    if (state.saving) return;
    state = state.copyWith(saving: true, fieldErrors: {}, conflicted: false);

    final outcome = await ref.read(itemRepositoryProvider).saveItem(item);

    state = switch (outcome) {
      ItemSaved() => state.copyWith(saving: false, saved: true),
      ItemRejected(:final fieldErrors) => state.copyWith(
        saving: false,
        fieldErrors: fieldErrors,
      ),
      ItemConflicted() => state.copyWith(saving: false, conflicted: true),
    };
  }
}

final itemEditorViewModelProvider =
    NotifierProvider<ItemEditorViewModel, ItemEditorState>(
      ItemEditorViewModel.new,
    );
