import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class CachedResponse {
  const CachedResponse({required this.body, required this.fetchedAt});

  final String body;
  final DateTime fetchedAt;
}

/// API レスポンスをエンドポイント単位でそのまま保存する。
///
/// サーバーのスキーマをクライアントに複製しないため、テーブルは1つで足りる。
/// リレーショナルなミラーを持たない決定がここに現れている。
abstract class ResponseCache {
  Future<CachedResponse?> read(String key);

  Future<void> write({
    required String key,
    required String body,
    required String userId,
  });

  Future<void> remove(String key);

  /// 認証ユーザーが切り替わったときに、そのユーザーの分だけを破棄する。
  Future<void> clearUser(String userId);
}

class SqfliteResponseCache implements ResponseCache {
  SqfliteResponseCache._(this._db);

  static const _table = 'response_cache';

  final Database _db;

  static Future<SqfliteResponseCache> open({String fileName = 'cache.db'}) async {
    final path = p.join(await getDatabasesPath(), fileName);
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_table (
          key TEXT PRIMARY KEY,
          body TEXT NOT NULL,
          fetched_at INTEGER NOT NULL,
          user_id TEXT NOT NULL
        )
      '''),
    );
    return SqfliteResponseCache._(db);
  }

  @override
  Future<CachedResponse?> read(String key) async {
    final rows = await _db.query(
      _table,
      columns: ['body', 'fetched_at'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    return CachedResponse(
      body: rows.first['body']! as String,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        rows.first['fetched_at']! as int,
      ),
    );
  }

  @override
  Future<void> write({
    required String key,
    required String body,
    required String userId,
  }) => _db.insert(_table, {
    'key': key,
    'body': body,
    'fetched_at': DateTime.now().millisecondsSinceEpoch,
    'user_id': userId,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> remove(String key) =>
      _db.delete(_table, where: 'key = ?', whereArgs: [key]);

  @override
  Future<void> clearUser(String userId) =>
      _db.delete(_table, where: 'user_id = ?', whereArgs: [userId]);
}
