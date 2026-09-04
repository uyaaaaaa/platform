import 'package:app/config/dependencies.dart';
import 'package:app/data/repositories/item_repository.dart';
import 'package:app/data/services/api_client.dart';
import 'package:app/ui/items/view_models/item_list_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/fake_response_cache.dart';

const _listBody = '''
[{"id":"1","title":"remote","done":false,"updatedAt":"2026-01-01T00:00:00.000Z"}]
''';

void main() {
  late FakeApiClient api;
  late FakeResponseCache cache;

  ProviderContainer build() {
    return ProviderContainer.test(
      retry: noAutomaticRetry,
      overrides: [
        itemRepositoryProvider.overrideWithValue(
          ItemRepository(api: api, cache: cache, userId: 'user-1'),
        ),
      ],
    );
  }

  setUp(() {
    api = FakeApiClient({'GET /items': const ApiResponse(200, _listBody)});
    cache = FakeResponseCache();
  });

  test('取得できた一覧が data として現れる', () async {
    final container = build();
    // provider は購読が無いと破棄されるため、読む前に購読する。
    container.listen(itemListViewModelProvider, (_, _) {});

    final items = await container.read(itemListViewModelProvider.future);

    expect(items.single.title, 'remote');
  });

  test('取得に失敗すると error になり、ViewModel は例外を捕まえない', () async {
    api.failure = ApiException('offline');
    final container = build();
    container.listen(itemListViewModelProvider, (_, _) {}, onError: (_, _) {});

    await expectLater(
      container.read(itemListViewModelProvider.future),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(itemListViewModelProvider), isA<AsyncError<void>>());
  });
}
