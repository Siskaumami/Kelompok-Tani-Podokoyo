import 'dart:convert';
import 'dart:io';

void verifyReleaseValues(Map<String, String> values) {
  final api = Uri.tryParse(values['API_BASE_URL'] ?? '');
  if (api == null ||
      api.scheme != 'https' ||
      api.host.isEmpty ||
      api.userInfo.isNotEmpty ||
      api.hasQuery ||
      api.hasFragment ||
      !['', '/', '/api/v1', '/api/v1/'].contains(api.path)) {
    throw const FormatException(
      'Release requires API_BASE_URL with an HTTPS service origin.',
    );
  }
  final origin = values['APP_ORIGIN'] ?? '';
  if (origin.isNotEmpty) {
    final app = Uri.tryParse(origin);
    if (app == null ||
        app.scheme != 'https' ||
        app.host.isEmpty ||
        app.userInfo.isNotEmpty ||
        app.hasQuery ||
        app.hasFragment ||
        !['', '/'].contains(app.path)) {
      throw const FormatException(
        'APP_ORIGIN must be an HTTPS origin matching server APP_URL.',
      );
    }
  }
}

void main(List<String> arguments) {
  try {
    final values = <String, String>{};
    for (final part in (Platform.environment['DART_DEFINES'] ?? '').split(
      ',',
    )) {
      if (part.isEmpty) continue;
      final decoded = utf8.decode(base64Decode(part));
      final equal = decoded.indexOf('=');
      if (equal > 0) {
        values[decoded.substring(0, equal)] = decoded.substring(equal + 1);
      }
    }
    for (final arg in arguments) {
      if (arg.startsWith('--API_BASE_URL=')) {
        values['API_BASE_URL'] = arg.substring(15);
      }
      if (arg.startsWith('--APP_ORIGIN=')) {
        values['APP_ORIGIN'] = arg.substring(13);
      }
    }
    verifyReleaseValues(values);
    stdout.writeln('Release transport configuration verified.');
  } on Object {
    stderr.writeln(
      'Release configuration invalid. Set HTTPS API_BASE_URL and, when needed, APP_ORIGIN.',
    );
    exitCode = 1;
  }
}
