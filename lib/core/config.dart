import 'package:flutter/foundation.dart';

/// Build-time settings.
///
/// The website address the app talks to. Override it at build time with
/// `--dart-define=API_BASE_URL=https://your-domain.com` (see codemagic.yaml).
class AppEnv {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://jankiagro.nextlogic.in',
  );

  static const String apiPath = '/api/app/v1';

  /// Release builds only ever talk to the website over HTTPS, so the login
  /// and the staff token can never travel in clear text.
  static String? get problem {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return 'The website address in this build is not valid.';
    if (uri.scheme != 'https' && !kDebugMode) return 'This build points to a website without HTTPS, which is not allowed.';
    return null;
  }

  static Uri endpoint(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    final prefix = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    return base.replace(path: '$prefix$apiPath/$path', queryParameters: (query == null || query.isEmpty) ? null : query);
  }
}
