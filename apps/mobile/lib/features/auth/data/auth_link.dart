import '../../../core/config/app_config.dart';

String tokenFromLink(String raw, AppConfig config, String expectedPath) {
  final value = raw.trim();
  if (RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) return value;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.origin != config.appOrigin ||
      uri.path != expectedPath ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery) {
    throw const FormatException(
      'Tautan tidak lengkap atau tidak sesuai. Gunakan tautan dari email pengelola.',
    );
  }
  final token = Uri.splitQueryString(uri.fragment)['token'] ?? '';
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
    throw const FormatException(
      'Tautan tidak lengkap. Gunakan tautan dari email pengelola.',
    );
  }
  return token;
}
