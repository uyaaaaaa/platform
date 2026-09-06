import 'package:app/config/dependencies.dart';
import 'package:app/data/repositories/item_repository.dart';
import 'package:app/data/services/api_client.dart';
import 'package:app/ui/items/widgets/item_list_screen.dart';
import 'package:flutter/material.dart';
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

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [
        itemRepositoryProvider.overrideWithValue(
          ItemRepository(api: api, cache: cache, userId: 'user-1'),
        ),
      ],
      child: const MaterialApp(home: ItemListScreen()),
    ),
  );

  setUp(() {
    api = FakeApiClient({'GET /items': const ApiResponse(200, _listBody)});
    cache = FakeResponseCache();
  });

  testWidgets('読み込み中は進捗を出し、取得後に一覧を出す', (tester) async {
    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('remote'), findsOneWidget);
  });

  testWidgets('失敗すると再試行だけを出し、原因は見せない', (tester) async {
    api.failure = ApiException('offline');

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('再試行'), findsOneWidget);
    expect(find.textContaining('offline'), findsNothing);
  });
}
