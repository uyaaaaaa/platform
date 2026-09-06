import 'package:app/config/dependencies.dart';
import 'package:app/data/repositories/item_repository.dart';
import 'package:app/data/services/api_client.dart';
import 'package:app/ui/items/view_models/item_editor_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/fake_response_cache.dart';

const _itemBody =
    '{"id":"1","title":"stored","done":false,"updatedAt":"2026-01-01T00:00:00.000Z"}';

void main() {
  late FakeApiClient api;
  late FakeResponseCache cache;

  final provider = itemEditorViewModelProvider('1');

  ProviderContainer build() {
    final container = ProviderContainer.test(
      retry: noAutomaticRetry,
      overrides: [
        itemRepositoryProvider.overrideWithValue(
          ItemRepository(api: api, cache: cache, userId: 'user-1'),
        ),
      ],
    );
    container.listen(provider, (_, _) {}, onError: (_, _) {});
    return container;
  }

  setUp(() {
    api = FakeApiClient({'GET /items/1': const ApiResponse(200, _itemBody)});
    cache = FakeResponseCache();
  });

  test('初期状態は Repository から読み込む', () async {
    final container = build();

    final state = await container.read(provider.future);

    expect(state.title, 'stored');
    expect(state.done, isFalse);
    expect(api.calls, ['GET /items/1']);
  });

  test('編集した値で保存する', () async {
    api.responses['PUT /items/1'] = const ApiResponse(200, _itemBody);
    final container = build();
    await container.read(provider.future);

    final viewModel = container.read(provider.notifier)
      ..changeTitle('edited')
      ..changeDone(true);
    await viewModel.save();

    expect(container.read(provider).requireValue.saved, isTrue);
    expect(api.calls, ['GET /items/1', 'PUT /items/1']);
  });

  test('409 は conflicted として状態に現れる', () async {
    api.responses['PUT /items/1'] = const ApiResponse(409, '');
    final container = build();
    await container.read(provider.future);

    await container.read(provider.notifier).save();

    final state = container.read(provider).requireValue;
    expect(state.conflicted, isTrue);
    expect(state.saved, isFalse);
  });

  test('422 のフィールドエラーが状態に現れる', () async {
    api.responses['PUT /items/1'] = const ApiResponse(
      422,
      '{"fieldErrors":{"title":"必須です"}}',
    );
    final container = build();
    await container.read(provider.future);

    await container.read(provider.notifier).save();

    expect(container.read(provider).requireValue.fieldErrors['title'], '必須です');
  });
}
