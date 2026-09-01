import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    userId: json['userId'] as String,
  );

  final String accessToken;
  final String refreshToken;
  final String userId;

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'userId': userId,
  };
}

/// トークンの保管。状態は持たず、変更を通知するだけに留める。
///
/// この抽象は3条件テスト(揮発性がある / 実装が2つ以上ある / テストで実物が
/// 使えない)のうち3つ目に合格する。OS の Keychain / Keystore はテストから
/// 触れない。
abstract class AuthTokenStore {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();

  /// 保管内容が変わったことだけを通知する。値は流さない。
  Stream<void> get changes;
}

class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_tokens';

  final FlutterSecureStorage _storage;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<AuthTokens?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return AuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    await _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
    _changes.add(null);
  }

  void dispose() => _changes.close();
}
