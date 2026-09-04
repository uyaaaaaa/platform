import 'dart:convert';

import '../../domain/models/item.dart';
import '../../domain/models/item_save_outcome.dart';
import '../services/api_client.dart';
import '../services/response_cache.dart';

class ItemRepository {
  ItemRepository({
    required this.api,
    required this.cache,
    required this.userId,
    this.ttl = const Duration(minutes: 5),
  });

  static const _listKey = 'GET /items';
  static const _listPath = '/items';

  final ApiClient api;
  final ResponseCache cache;
  final String userId;

  final Duration ttl;

  Stream<List<Item>> watchItems() async* {
    final cached = await cache.read(_listKey);
    var served = false;

    if (cached != null) {
      yield _decodeList(cached.body);
      served = true;
      if (DateTime.now().difference(cached.fetchedAt) < ttl) return;
    }

    try {
      final response = await api.send('GET', _listPath);
      if (response.statusCode != 200) {
        throw ApiException('GET $_listPath failed with ${response.statusCode}');
      }
      await cache.write(key: _listKey, body: response.body, userId: userId);
      yield _decodeList(response.body);
    } on Exception {
      if (!served) rethrow;
    }
  }

  Future<ItemSaveOutcome> saveItem(Item item) async {
    final response = await api.send(
      'PUT',
      '$_listPath/${item.id}',
      body: item.toJson(),
    );

    switch (response.statusCode) {
      case 200:
        await cache.remove(_listKey);
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ItemSaved(Item.fromJson(json));
      case 409:
        return const ItemConflicted();
      case 422:
        return ItemRejected(_decodeFieldErrors(response.body));
      default:
        throw ApiException('PUT failed with ${response.statusCode}');
    }
  }

  Future<void> deleteItem(String id) async {
    final response = await api.send('DELETE', '$_listPath/$id');
    if (response.statusCode != 204) {
      throw ApiException('DELETE failed with ${response.statusCode}');
    }
    await cache.remove(_listKey);
  }

  List<Item> _decodeList(String body) {
    final json = jsonDecode(body) as List<dynamic>;
    return json
        .map((e) => Item.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Map<String, String> _decodeFieldErrors(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final errors = json['fieldErrors'] as Map<String, dynamic>? ?? {};
    return errors.map((key, value) => MapEntry(key, value.toString()));
  }
}
