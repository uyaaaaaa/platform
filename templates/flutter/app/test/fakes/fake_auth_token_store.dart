import 'dart:async';

import 'package:app/data/services/auth_token_store.dart';

class FakeAuthTokenStore implements AuthTokenStore {
  FakeAuthTokenStore([this._tokens]);

  final _changes = StreamController<void>.broadcast();

  AuthTokens? _tokens;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async {
    _tokens = tokens;
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    _tokens = null;
    _changes.add(null);
  }

  void dispose() => _changes.close();
}
