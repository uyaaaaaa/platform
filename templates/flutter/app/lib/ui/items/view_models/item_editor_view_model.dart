import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/dependencies.dart';
import '../../../domain/models/item.dart';
import '../../../domain/models/item_save_outcome.dart';

class ItemEditorState {
  const ItemEditorState({
    required this.title,
    required this.done,
    required this.updatedAt,
    this.saving = false,
    this.fieldErrors = const {},
    this.conflicted = false,
    this.saved = false,
  });

  final String title;
  final bool done;
  final DateTime updatedAt;
  final bool saving;
  final Map<String, String> fieldErrors;
  final bool conflicted;
  final bool saved;

  ItemEditorState copyWith({
    String? title,
    bool? done,
    bool? saving,
    Map<String, String>? fieldErrors,
    bool? conflicted,
    bool? saved,
  }) => ItemEditorState(
    title: title ?? this.title,
    done: done ?? this.done,
    updatedAt: updatedAt,
    saving: saving ?? this.saving,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    conflicted: conflicted ?? this.conflicted,
    saved: saved ?? this.saved,
  );
}

class ItemEditorViewModel extends AsyncNotifier<ItemEditorState> {
  ItemEditorViewModel(this.itemId);

  final String itemId;

  @override
  Future<ItemEditorState> build() async {
    final item = await ref.watch(itemRepositoryProvider).getItem(itemId);
    return ItemEditorState(
      title: item.title,
      done: item.done,
      updatedAt: item.updatedAt,
    );
  }

  void changeTitle(String title) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(title: title));
  }

  void changeDone(bool done) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(done: done));
  }

  Future<void> save() async {
    final current = state.value;
    if (current == null || current.saving) return;

    state = AsyncData(
      current.copyWith(saving: true, fieldErrors: {}, conflicted: false),
    );

    final outcome = await ref
        .read(itemRepositoryProvider)
        .saveItem(
          Item(
            id: itemId,
            title: current.title,
            done: current.done,
            updatedAt: current.updatedAt,
          ),
        );

    state = AsyncData(switch (outcome) {
      ItemSaved() => current.copyWith(saving: false, saved: true),
      ItemRejected(:final fieldErrors) => current.copyWith(
        saving: false,
        fieldErrors: fieldErrors,
      ),
      ItemConflicted() => current.copyWith(saving: false, conflicted: true),
    });
  }
}

final itemEditorViewModelProvider =
    AsyncNotifierProvider.family<ItemEditorViewModel, ItemEditorState, String>(
      ItemEditorViewModel.new,
    );
