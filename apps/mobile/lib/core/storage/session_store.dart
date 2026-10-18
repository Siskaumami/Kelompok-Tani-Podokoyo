import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/app_error.dart';

class SessionCookie {
  const SessionCookie(this.name, this.value, this.expires);
  factory SessionCookie.decode(String text) {
    final data = jsonDecode(text);
    if (data is! Map ||
        !['__Host-tani_session', 'tani_session'].contains(data['name']) ||
        data['value'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['value'] as String) ||
        data['expires'] is! String) {
      throw const FormatException('Invalid session');
    }
    final expires = DateTime.parse(data['expires'] as String);
    return SessionCookie(
      data['name'] as String,
      data['value'] as String,
      expires,
    );
  }
  final String name;
  final String value;
  final DateTime expires;
  bool get expired => !expires.isAfter(DateTime.now());
  String get header => '$name=$value';
  String encode() => jsonEncode({
    'name': name,
    'value': value,
    'expires': expires.toUtc().toIso8601String(),
  });
  @override
  String toString() => 'SessionCookie([redacted])';
}

abstract interface class SessionStore {
  Future<SessionCookie?> read();
  Future<void> write(SessionCookie cookie);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore(this.key, {FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );
  final String key;
  final FlutterSecureStorage _storage;

  @override
  Future<SessionCookie?> read() async {
    try {
      final value = await _storage.read(key: key);
      if (value == null) return null;
      final cookie = SessionCookie.decode(value);
      if (cookie.expired) {
        await clear();
        return null;
      }
      return cookie;
    } on FormatException {
      await clear();
      return null;
    } catch (_) {
      throw const AppError(
        'Penyimpanan aman perangkat belum dapat dibaca. Coba lagi.',
        code: 'SECURE_STORAGE',
      );
    }
  }

  @override
  Future<void> write(SessionCookie cookie) async {
    try {
      await _storage.write(key: key, value: cookie.encode());
    } catch (_) {
      throw const AppError(
        'Sesi belum dapat disimpan dengan aman. Coba masuk kembali.',
        code: 'SECURE_STORAGE',
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      throw const AppError(
        'Sesi perangkat belum dapat dihapus. Coba lagi.',
        code: 'SECURE_STORAGE',
      );
    }
  }
}
