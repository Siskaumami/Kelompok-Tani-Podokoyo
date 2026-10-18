import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._(this.apiBase, this.appOrigin, this.release);

  factory AppConfig.parse(
    String base, {
    String origin = '',
    bool release = kReleaseMode,
  }) {
    final uri = Uri.tryParse(base.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['', '/', '/api/v1', '/api/v1/'].contains(uri.path)) {
      throw const FormatException(
        'Isi API_BASE_URL dengan alamat layanan yang valid.',
      );
    }
    if (release && uri.scheme != 'https') {
      throw const FormatException('Aplikasi rilis memerlukan alamat HTTPS.');
    }
    final app = origin.trim().isEmpty
        ? Uri.parse(uri.origin)
        : Uri.tryParse(origin.trim());
    if (app == null ||
        !app.hasAuthority ||
        app.host.isEmpty ||
        !['https', 'http'].contains(app.scheme) ||
        app.userInfo.isNotEmpty ||
        !['', '/'].contains(app.path) ||
        app.hasQuery ||
        app.hasFragment ||
        (release && app.scheme != 'https')) {
      throw const FormatException(
        'APP_ORIGIN harus sama dengan origin APP_URL pada layanan.',
      );
    }
    return AppConfig._('${uri.origin}/api/v1', app.origin, release);
  }

  factory AppConfig.environment() => AppConfig.parse(
    const String.fromEnvironment('API_BASE_URL'),
    origin: const String.fromEnvironment('APP_ORIGIN'),
  );

  final bool release;
  final String apiBase;
  final String appOrigin;
  Uri get server => Uri.parse(apiBase);
  String get sessionKey => 'tani.mobile.session.v1.${server.origin}';

  Uri apiUri(String path) {
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('://') ||
        path.contains('..') ||
        path.contains('#')) {
      throw const FormatException('Alamat permintaan tidak valid.');
    }
    return Uri.parse('$apiBase$path');
  }
}
