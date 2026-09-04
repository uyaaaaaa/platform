import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/repositories/auth_repository.dart';
import '../data/repositories/item_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/auth_token_store.dart';
import '../data/services/response_cache.dart';
import '../domain/models/auth_status.dart';
import 'app_config.dart';

// Riverpod 3 の既定は最大10回の指数バックオフ再試行。
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
