import 'package:app/data/repositories/item_repository.dart';
import 'package:app/data/services/api_client.dart';
import 'package:app/domain/models/item.dart';
import 'package:app/domain/models/item_save_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/fake_response_cache.dart';

const _listBody = '''
[{"id":"1","title":"remote","done":false,"updatedAt":"2026-01-01T00:00:00.000Z"}]
''';
const _cachedBody = '''
[{"id":"1","title":"cached","done":false,"updatedAt":"2026-01-01T00:00:00.000Z"}]
''';

const _savedBody =
    '{"id":"1","title":"updated","done":true,"updatedAt":"2026-01-01T00:00:00.000Z"}';

void main() {
  late FakeApiClient api;
  late FakeResponseCache cache;

  ItemRepository build({Duration ttl = const Duration(minutes: 5)}) =>
      ItemRepository(api: api, cache: cache, userId: 'user-1', ttl: ttl);

  setUp(() {
    api = FakeApiClient({'GET /items': const ApiResponse(200, _listBody)});
    cache = FakeResponseCache();
  });

  group('watchItems', () {
    test('保存済みが無ければ取得結果だけを流す', () async {
      final emitted = await build().watchItems().toList();

      expect(emitted, hasLength(1));
      expect(emitted.single.single.title, 'remote');
      expect(cache.entries, contains('GET /items'));
    });

    test('保存済みが古ければ、先に保存済みを流してから取得結果を流す', () async {
      cache.seed(
        key: 'GET /items',
        body: _cachedBody,
        fetchedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final emitted = await build().watchItems().toList();

      expect(emitted.map((e) => e.single.title), ['cached', 'remote']);
    });

    test('保存済みが新しければ API を呼ばない', () async {
      cache.seed(
        key: 'GET /items',
        body: _cachedBody,
        fetchedAt: DateTime.now(),
      );

      final emitted = await build().watchItems().toList();

      expect(emitted.map((e) => e.single.title), ['cached']);
      expect(api.calls, isEmpty);
    });

    test('取得に失敗しても、保存済みを流していれば失敗にしない', () async {
      cache.seed(
        key: 'GET /items',
        body: _cachedBody,
        fetchedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      api.failure = ApiException('offline');

      final emitted = await build().watchItems().toList();

      expect(emitted.map((e) => e.single.title), ['cached']);
    });

    test('保存済みが無く取得にも失敗したら例外を投げる', () {
      api.failure = ApiException('offline');

      expect(build().watchItems(), emitsError(isA<ApiException>()));
    });
  });

  group('saveItem', () {
    final item = Item(
      id: '1',
      title: 'updated',
      done: true,
      updatedAt: DateTime.utc(2026),
    );

    test('200 なら保存済みを破棄して ItemSaved を返す', () async {
      cache.seed(
        key: 'GET /items',
        body: _cachedBody,
        fetchedAt: DateTime.now(),
      );
      api.responses['PUT /items/1'] = const ApiResponse(200, _savedBody);

      final outcome = await build().saveItem(item);

      expect(outcome, isA<ItemSaved>());
      expect(cache.entries, isEmpty);
    });

    test('422 は例外ではなく ItemRejected として返る', () async {
      api.responses['PUT /items/1'] = const ApiResponse(
        422,
        '{"fieldErrors":{"title":"必須です"}}',
      );

      final outcome = await build().saveItem(item);

      expect(outcome, isA<ItemRejected>());
      expect((outcome as ItemRejected).fieldErrors['title'], '必須です');
    });

    test('409 は ItemConflicted として返る', () async {
      api.responses['PUT /items/1'] = const ApiResponse(409, '');

      expect(await build().saveItem(item), isA<ItemConflicted>());
    });

    test('500 は予期しない失敗として投げる', () async {
      api.responses['PUT /items/1'] = const ApiResponse(500, '');

      expect(build().saveItem(item), throwsA(isA<ApiException>()));
    });
  });
}
