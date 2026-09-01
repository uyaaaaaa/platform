import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/dependencies.dart';
import '../../../domain/models/item.dart';

/// 一覧の状態。
///
/// 保存済みのレスポンスと取得し直した結果が順に流れてくるため Stream で受ける。
/// キャッシュの存在は Repository の内側にあり、ここからは見えない。
class ItemListViewModel extends StreamNotifier<List<Item>> {
  @override
  Stream<List<Item>> build() => ref.watch(itemRepositoryProvider).watchItems();

  /// 再取得。AsyncValue が loading と error を引き受けるため、
  /// ここで例外を捕まえない。
  void refresh() => ref.invalidateSelf();
}

final itemListViewModelProvider =
    StreamNotifierProvider<ItemListViewModel, List<Item>>(
      ItemListViewModel.new,
    );
