import 'dart:async';
import 'dart:convert';

import '../../domain/models/auth_status.dart';
import '../../domain/models/sign_in_outcome.dart';
import '../services/api_client.dart';
import '../services/auth_token_store.dart';
import '../services/response_cache.dart';

class AuthRepository {
  AuthRepository({
    required this.api,
    required this.tokenStore,
    required this.cache,
  }) {
    _subscription = tokenStore.changes.listen((_) => _refreshStatus());
    unawaited(_refreshStatus());
  }

  final ApiClient api;
  final AuthTokenStore tokenStore;
  final ResponseCache cache;

  final _statusChanges = StreamController<AuthStatus>.broadcast();

  StreamSubscription<void>? _subscription;
  AuthStatus _status = AuthStatus.unknown;
  String? _userId;

  AuthStatus get status => _status;

  String? get userId => _userId;

  Stream<AuthStatus> get statusChanges => _statusChanges.stream;

  Future<SignInOutcome> signIn({
    required String email,
    required String password,
  }) async {
    final response = await api.send(
      'POST',
      '/auth/sign-in',
      body: {'email': email, 'password': password},
    );

    if (response.statusCode == 401) {
      return const SignInRejected('メールアドレスまたはパスワードが違います。');
    }
    if (response.statusCode != 200) {
      throw ApiException('sign-in failed with ${response.statusCode}');
    }

    await tokenStore.write(
      AuthTokens.fromJson(jsonDecode(response.body) as Map<String, dynamic>),
    );
    return const SignInSucceeded();
  }

  Future<void> signOut() async {
    final previous = _userId;
    if (previous != null) await cache.clearUser(previous);
    await tokenStore.clear();
  }

  Future<void> _refreshStatus() async {
    final stored = await tokenStore.read();
    _userId = stored?.userId;
    _status = stored == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    if (!_statusChanges.isClosed) _statusChanges.add(_status);
  }

  void dispose() {
    _subscription?.cancel();
    _statusChanges.close();
  }
}
