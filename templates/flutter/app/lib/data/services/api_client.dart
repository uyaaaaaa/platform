import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_token_store.dart';

class ApiResponse {
  const ApiResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => 'ApiException: $message';
}

abstract class ApiClient {
  Future<ApiResponse> send(
    String method,
    String path, {
    Map<String, Object?>? body,
  });
}

class HttpApiClient implements ApiClient {
  HttpApiClient({
    required this.client,
    required this.baseUrl,
    required this.tokenStore,
  });

  final http.Client client;
  final Uri baseUrl;
  final AuthTokenStore tokenStore;

  @override
  Future<ApiResponse> send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final current = await tokenStore.read();
    final response = await _dispatch(method, path, body, current?.accessToken);
    if (response.statusCode != 401 || current == null) return response;

    final refreshed = await _refresh(current);
    if (refreshed == null) {
      await tokenStore.clear();
      return response;
    }

    return _dispatch(method, path, body, refreshed.accessToken);
  }

  Future<ApiResponse> _dispatch(
    String method,
    String path,
    Map<String, Object?>? body,
    String? accessToken,
  ) async {
    final request = http.Request(method, baseUrl.resolve(path))
      ..headers['accept'] = 'application/json';
    if (accessToken != null) {
      request.headers['authorization'] = 'Bearer $accessToken';
    }
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    try {
      final streamed = await client.send(request);
      final text = await streamed.stream.bytesToString();
      return ApiResponse(streamed.statusCode, text);
    } on http.ClientException catch (error) {
      throw ApiException(error.message);
    }
  }

  Future<AuthTokens?> _refresh(AuthTokens current) async {
    final response = await _dispatch('POST', '/auth/refresh', {
      'refreshToken': current.refreshToken,
    }, null);
    if (response.statusCode != 200) return null;

    final refreshed = AuthTokens.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await tokenStore.write(refreshed);
    return refreshed;
  }
}
