/// 環境ごとに変わる値。--dart-define で渡し、コードに埋め込まない。
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8787',
    ),
  );

  final String apiBaseUrl;
}
