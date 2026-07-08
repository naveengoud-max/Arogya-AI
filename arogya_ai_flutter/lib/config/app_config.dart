class AppConfig {
  /// Base API URL for the backend service.
  /// Can be overridden at build time using:
  /// flutter build apk --dart-define=BACKEND_URL=https://your-production-domain.com/api
  static const String defaultBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );
}
