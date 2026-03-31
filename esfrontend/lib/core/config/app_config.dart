class AppConfig {
  const AppConfig._();

  static const String defaultLang = 'es';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.34:3000/api/v1',
  );
}
