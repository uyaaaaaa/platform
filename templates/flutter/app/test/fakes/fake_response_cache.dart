import 'package:app/data/services/response_cache.dart';

class FakeResponseCache implements ResponseCache {
  final Map<String, CachedResponse> entries = {};
  final Map<String, String> owners = {};

  @override
  Future<CachedResponse?> read(String key) async => entries[key];

  @override
  Future<void> write({
    required String key,
    required String body,
    required String userId,
  }) async {
    entries[key] = CachedResponse(body: body, fetchedAt: DateTime.now());
    owners[key] = userId;
  }

  @override
  Future<void> remove(String key) async {
    entries.remove(key);
    owners.remove(key);
  }

  @override
  Future<void> clearUser(String userId) async {
    owners.removeWhere((key, owner) {
      if (owner != userId) return false;
      entries.remove(key);
      return true;
    });
  }

  void seed({
    required String key,
    required String body,
    required DateTime fetchedAt,
    String userId = 'user-1',
  }) {
    entries[key] = CachedResponse(body: body, fetchedAt: fetchedAt);
    owners[key] = userId;
  }
}
