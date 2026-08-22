import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _envUrl = String.fromEnvironment('BACKEND_URL');

  /// Base API URL for the backend service.
  /// Can be overridden at build time using:
  /// flutter build apk --dart-define=BACKEND_URL=https://your-production-domain.com/api
  static String get defaultBackendUrl {
    if (_envUrl.isNotEmpty) {
      return _envUrl;
    }
    if (kIsWeb) {
      return '/api';
    }
    // Default 24/7 Cloud Backend URL (Works on mobile phones without laptop localhost)
    return 'https://arogya-ai-backend.onrender.com/api';
  }
}

