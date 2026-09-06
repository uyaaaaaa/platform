import 'package:app/data/services/api_client.dart';

class FakeApiClient implements ApiClient {
  FakeApiClient(this.responses);

  // キーは '<METHOD> <path>'
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
