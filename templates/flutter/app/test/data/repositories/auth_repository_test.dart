import 'package:app/data/repositories/auth_repository.dart';
import 'package:app/data/services/api_client.dart';
import 'package:app/data/services/auth_token_store.dart';
import 'package:app/domain/models/auth_status.dart';
import 'package:app/domain/models/sign_in_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/fake_auth_token_store.dart';
import '../../fakes/fake_response_cache.dart';

const _tokensBody =
    '{"accessToken":"a","refreshToken":"r","userId":"user-1"}';

void main() {
  late FakeApiClient api;
  late FakeAuthTokenStore tokenStore;
  late FakeResponseCache cache;
  late AuthRepository repository;

  setUp(() {
    api = FakeApiClient({
      'POST /auth/sign-in': const ApiResponse(200, _tokensBody),
    });
    tokenStore = FakeAuthTokenStore();
    cache = FakeResponseCache();
    repository = AuthRepository(
      api: api,
      tokenStore: tokenStore,
      cache: cache,
    );
  });

  tearDown(() {
    repository.dispose();
    tokenStore.dispose();
  });

  test('サインインするとトークンが保管され、状態が signedIn になる', () async {
    expect(await repository.signIn(email: 'a@example.com', password: 'p'),
        isA<SignInSucceeded>());

    await expectLater(
      repository.statusChanges,
      emitsThrough(AuthStatus.signedIn),
    );
    expect(repository.userId, 'user-1');
  });

  test('401 は例外ではなく SignInRejected として返る', () async {
    api.responses['POST /auth/sign-in'] = const ApiResponse(401, '');

    final outcome =
        await repository.signIn(email: 'a@example.com', password: 'bad');

    expect(outcome, isA<SignInRejected>());
  });

  test('サインアウトはそのユーザーのキャッシュを破棄する', () async {
    await tokenStore.write(
      const AuthTokens(accessToken: 'a', refreshToken: 'r', userId: 'user-1'),
    );
    await repository.statusChanges.firstWhere((s) => s == AuthStatus.signedIn);
    cache.seed(
      key: 'GET /items',
      body: '[]',
      fetchedAt: DateTime.now(),
    );

    await repository.signOut();

    expect(cache.entries, isEmpty);
    expect(await tokenStore.read(), isNull);
  });
}
