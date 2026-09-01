import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/repositories/auth_repository.dart';
import '../data/repositories/item_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/auth_token_store.dart';
import '../data/services/response_cache.dart';
import '../domain/models/auth_status.dart';
import 'app_config.dart';

/// DI の組み立てをここ1箇所に集める。
///
/// テストと main.dart の差はこのファイルの override だけであり、
/// 実装クラスを直接参照するのはここだけになる。

/// 失敗した provider を Riverpod に自動で再試行させない。
///
/// Riverpod 3 の既定は最大10回の指数バックオフ再試行であり、1画面の失敗が
/// 最大11リクエストに膨らむ。Workers Free の 10万リクエスト/日 に対して
/// これは無視できず、閲覧キャッシュで抑えた分を打ち消す。再試行は利用者の
/// 明示的な操作としてのみ行い、要求数を予測可能に保つ。
Duration? noAutomaticRetry(int retryCount, Object error) => null;

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final authTokenStoreProvider = Provider<AuthTokenStore>((ref) {
  final store = SecureAuthTokenStore();
  ref.onDispose(store.dispose);
  return store;
});

/// 実体は起動時に main.dart から override する。
/// sqflite の初期化は非同期であり、Provider の同期的な構築には載らない。
final responseCacheProvider = Provider<ResponseCache>(
  (ref) => throw UnimplementedError('responseCacheProvider must be overridden'),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => HttpApiClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Uri.parse(ref.watch(appConfigProvider).apiBaseUrl),
    tokenStore: ref.watch(authTokenStoreProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = AuthRepository(
    api: ref.watch(apiClientProvider),
    tokenStore: ref.watch(authTokenStoreProvider),
    cache: ref.watch(responseCacheProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final authStatusProvider = StreamProvider<AuthStatus>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.statusChanges;
});

/// 認証ユーザーが変わると作り直される。前のユーザーのキャッシュ鍵を
/// 引き継がないことが型の上で保証される。
final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  final userId = ref.watch(authRepositoryProvider).userId;
  if (userId == null) {
    throw StateError('itemRepositoryProvider requires a signed-in user');
  }
  return ItemRepository(
    api: ref.watch(apiClientProvider),
    cache: ref.watch(responseCacheProvider),
    userId: userId,
  );
});
