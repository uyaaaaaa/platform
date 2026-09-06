import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/dependencies.dart';
import '../../../domain/models/item.dart';

class ItemListViewModel extends StreamNotifier<List<Item>> {
  @override
  Stream<List<Item>> build() => ref.watch(itemRepositoryProvider).watchItems();

  void refresh() => ref.invalidateSelf();
}

final itemListViewModelProvider =
    StreamNotifierProvider<ItemListViewModel, List<Item>>(
      ItemListViewModel.new,
    );
