abstract final class AppConfig {
  static const apiEnabled = bool.fromEnvironment(
    'API_ENABLED',
    defaultValue: false,
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const githubRawBaseUrl = String.fromEnvironment(
    'GITHUB_RAW_BASE_URL',
    defaultValue: '',
  );

  static bool get remoteJsonEnabled =>
      !apiEnabled && githubRawBaseUrl.trim().isNotEmpty;
}
