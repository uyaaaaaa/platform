import 'package:app/data/services/api_client.dart';

/// mock ではなく fake を作る(Flutter 公式 strong 推奨)。
///
/// fake は入力と出力にしか関心がないため、fake を書ける形に保とうとすること
/// 自体が、Service の輪郭を単純に保つ圧力になる。
class FakeApiClient implements ApiClient {
  FakeApiClient(this.responses);

  /// `'<METHOD> <path>'` -> 返す応答。
  final Map<String, ApiResponse> responses;

  final List<String> calls = [];

  Exception? failure;

  @override
  Future<ApiResponse> send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    calls.add('$method $path');
    if (failure != null) throw failure!;

    final response = responses['$method $path'];
    if (response == null) throw ApiException('unexpected call: $method $path');
    return response;
  }
}
