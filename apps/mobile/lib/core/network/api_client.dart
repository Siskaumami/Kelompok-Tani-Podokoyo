import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../errors/app_error.dart';
import '../storage/session_store.dart';
import 'json_data.dart';
import 'mutation.dart';

class ApiClient {
  ApiClient(this.config, this.store, {Dio? dio, this._anonymousClient})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 25),
              sendTimeout: const Duration(seconds: 25),
              receiveTimeout: const Duration(seconds: 25),
              followRedirects: false,
            ),
          );
  final AppConfig config;
  final SessionStore store;
  final Dio _dio;
  final Dio Function()? _anonymousClient;
  SessionCookie? _cookie;
  String _csrf = '';
  int _generation = 0;
  Future<void> Function()? onSessionExpired;
  bool get hasSession => _cookie != null && !_cookie!.expired;

  Future<bool> restoreCookie() async {
    _cookie = await store.read();
    return hasSession;
  }

  void setCsrf(String value) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) throw AppError.malformed();
    _csrf = value;
  }

  Future<void> clearSession() async {
    _generation++;
    _cookie = null;
    _csrf = '';
    await store.clear();
  }

  Future<Object?> get(
    String path, {
    bool authenticated = true,
    CancelToken? cancelToken,
  }) async {
    final response = await _request(
      path,
      authenticated: authenticated,
      cancelToken: cancelToken,
    );
    return _envelope(response.data);
  }

  Future<Object?> mutate(PendingMutation mutation) async {
    final response = await _request(
      mutation.path,
      method: mutation.method,
      data: mutation.encoded,
      key: mutation.key,
    );
    return _envelope(response.data, write: true);
  }

  Future<Object?> authPost(
    String path,
    Json payload, {
    bool authenticated = false,
  }) async {
    final response = await _request(
      path,
      method: 'POST',
      data: payload,
      authenticated: authenticated,
    );
    if (path == '/auth/login') {
      try {
        _envelope(response.data, write: true);
        final session = _sessionCookie(
          response.headers['set-cookie'] ?? const [],
        );
        await store.write(session);
        _cookie = session;
        _generation++;
      } catch (_) {
        await clearSession();
        rethrow;
      }
    }
    return _envelope(response.data, write: true);
  }

  SessionCookie _sessionCookie(List<String> headers) {
    for (final header in headers) {
      Cookie parsed;
      try {
        parsed = Cookie.fromSetCookieValue(header);
      } on FormatException {
        continue;
      }
      if (!['__Host-tani_session', 'tani_session'].contains(parsed.name)) {
        continue;
      }
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(parsed.value) ||
          (config.release &&
              (parsed.name != '__Host-tani_session' || !parsed.secure)) ||
          (parsed.name == '__Host-tani_session' && !parsed.secure) ||
          (parsed.secure && config.server.scheme != 'https') ||
          (parsed.domain?.isNotEmpty ?? false) ||
          parsed.path != '/' ||
          !parsed.httpOnly) {
        throw AppError.malformed();
      }
      final lifetime = parsed.maxAge;
      if (lifetime == null || lifetime <= 0 || lifetime > 43200) {
        throw AppError.malformed();
      }
      return SessionCookie(
        parsed.name,
        parsed.value,
        DateTime.now().add(Duration(seconds: lifetime)),
      );
    }
    throw const AppError(
      'Sesi masuk tidak diterima. Periksa konfigurasi layanan.',
      code: 'SESSION_COOKIE_MISSING',
    );
  }

  Object? _envelope(Object? body, {bool write = false}) {
    if (body is! Map || !body.containsKey('data')) {
      throw AppError.malformed(write: write);
    }
    final data = body['data'];
    if (write && (data is! Map || data.isEmpty)) {
      throw AppError.malformed(write: true);
    }
    return data;
  }

  Future<Response<Object?>> _request(
    String path, {
    String method = 'GET',
    Object? data,
    String? key,
    bool authenticated = true,
    CancelToken? cancelToken,
    ResponseType responseType = ResponseType.json,
    bool redirect = false,
  }) async {
    final write = method != 'GET';
    final generation = _generation;
    if (authenticated && !hasSession) {
      if (_cookie != null || _csrf.isNotEmpty) await _expire();
      throw const AppError(
        'Silakan masuk untuk melanjutkan.',
        code: 'AUTH_REQUIRED',
        status: 401,
      );
    }
    try {
      final headers = <String, Object>{
        'Accept': 'application/json',
        'Cache-Control': 'no-store',
        if (authenticated) 'Cookie': _cookie!.header,
        if (write) 'Origin': config.appOrigin,
        if (write && authenticated) 'X-CSRF-Token': _csrf,
        'Idempotency-Key': ?key,
      };
      final response = await _dio.requestUri<Object?>(
        config.apiUri(path),
        data: data,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: headers,
          contentType: data is FormData
              ? 'multipart/form-data'
              : 'application/json',
          responseType: responseType,
          followRedirects: false,
          validateStatus: (status) =>
              status != null &&
              ((status >= 200 && status < 300) || (redirect && status == 302)),
        ),
      );
      if (authenticated && generation != _generation) {
        throw const AppError(
          'Sesi berubah. Silakan masuk kembali.',
          code: 'AUTH_REQUIRED',
          status: 401,
        );
      }
      return response;
    } catch (error) {
      final mapped = AppError.from(error, write: write);
      if (authenticated && mapped.sessionExpired && generation == _generation) {
        await _expire();
      }
      throw mapped;
    }
  }

  Future<void> _expire() async {
    try {
      await clearSession();
    } finally {
      await onSessionExpired?.call();
    }
  }

  Future<Object?> upload(Uint8List bytes, String filename, String key) async {
    validateImage(bytes);
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _request(
      '/files',
      method: 'POST',
      data: form,
      key: key,
    );
    return _envelope(response.data, write: true);
  }

  /// Only the authorization request carries cookies. Signed storage reads are anonymous.
  Future<Uint8List> image(String id, {CancelToken? cancelToken}) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) throw AppError.malformed();
    final response = await _request(
      '/files/$id',
      redirect: true,
      cancelToken: cancelToken,
    );
    if (response.statusCode != 302) throw AppError.malformed();
    final location = Uri.tryParse(response.headers.value('location') ?? '');
    if (location == null ||
        location.scheme != 'https' ||
        !location.hasAuthority ||
        location.userInfo.isNotEmpty ||
        !(location.host == 's3.filebase.io' ||
            location.host.endsWith('.s3.filebase.io'))) {
      throw AppError.malformed();
    }
    final anonymous =
        _anonymousClient?.call() ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 25),
            receiveTimeout: const Duration(seconds: 25),
            followRedirects: false,
          ),
        );
    final token = cancelToken ?? CancelToken();
    try {
      final image = await anonymous.get<List<int>>(
        location.toString(),
        cancelToken: token,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, _) {
          if (received > 10 * 1024 * 1024) token.cancel();
        },
      );
      final bytes = Uint8List.fromList(image.data ?? []);
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        throw AppError.malformed();
      }
      return bytes;
    } catch (error) {
      throw AppError.from(error);
    } finally {
      anonymous.close();
    }
  }

  void close() => _dio.close(force: true);
}

void validateImage(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    throw const AppError(
      'Ukuran gambar maksimal 5 MB.',
      code: 'FILE_TOO_LARGE',
    );
  }
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  final png =
      bytes.length >= 8 &&
      bytes[0] == 137 &&
      String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG' &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10;
  final webp =
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
  if (!jpeg && !png && !webp) {
    throw const AppError(
      'Gunakan gambar JPEG, PNG atau WebP.',
      code: 'FILE_TYPE',
    );
  }
}
