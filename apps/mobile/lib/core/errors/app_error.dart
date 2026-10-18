import 'package:dio/dio.dart';

class FieldIssue {
  const FieldIssue(this.field, this.message);
  final String field;
  final String message;
}

class AppError implements Exception {
  const AppError(
    this.message, {
    this.code = 'CLIENT_ERROR',
    this.status = 0,
    this.issues = const [],
    this.requestId,
    this.uncertain = false,
  });

  final String message;
  final String code;
  final int status;
  final List<FieldIssue> issues;
  final String? requestId;
  final bool uncertain;
  bool get sessionExpired =>
      status == 401 || code == 'ACCOUNT_CHANGED' || code == 'CSRF_REJECTED';
  bool get staleBaseline => code == 'STALE_BASELINE';

  static AppError malformed({bool write = false}) => AppError(
    'Data belum dapat dibaca. Muat ulang lalu coba lagi.',
    code: 'MALFORMED_RESPONSE',
    uncertain: write,
  );

  factory AppError.response(int status, Object? body, {bool write = false}) {
    final outer = body is Map ? body['error'] : null;
    final error = outer is Map ? outer : const <String, Object?>{};
    final details = error['details'];
    final issues = <FieldIssue>[];
    if (details is List) {
      for (final value in details) {
        if (value is Map &&
            value['field'] is String &&
            value['message'] is String) {
          issues.add(
            FieldIssue(value['field'] as String, value['message'] as String),
          );
        }
      }
    }
    return AppError(
      error['message'] is String
          ? error['message'] as String
          : switch (status) {
              401 => 'Silakan masuk untuk melanjutkan.',
              403 => 'Anda tidak memiliki akses untuk tindakan ini.',
              404 => 'Data tidak ditemukan.',
              409 => 'Data berubah. Muat ulang dan periksa kembali.',
              422 => 'Periksa isian yang belum sesuai.',
              429 => 'Permintaan terlalu sering. Tunggu sebentar.',
              503 => 'Layanan sedang tidak tersedia. Coba lagi beberapa saat.',
              _ =>
                'Permintaan belum berhasil. Coba lagi atau hubungi pengelola.',
            },
      status: status,
      code: error['code'] is String ? error['code'] as String : 'HTTP_ERROR',
      requestId: error['request_id'] is String
          ? error['request_id'] as String
          : null,
      issues: List.unmodifiable(issues),
      uncertain: write && status >= 500,
    );
  }

  static AppError from(Object error, {bool write = false}) {
    if (error is AppError) return error;
    if (error is DioException) {
      if (error.response != null) {
        return AppError.response(
          error.response!.statusCode ?? 500,
          error.response!.data,
          write: write,
        );
      }
      final timeout = [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ].contains(error.type);
      return AppError(
        write
            ? 'Koneksi terputus saat menyimpan. Data mungkin sudah tersimpan. Coba lagi untuk memastikan.'
            : timeout
            ? 'Waktu tunggu habis. Periksa koneksi lalu coba lagi.'
            : 'Data belum dapat dimuat. Periksa koneksi internet.',
        code: timeout ? 'TIMEOUT' : 'NETWORK_ERROR',
        uncertain: write,
      );
    }
    if (error is FormatException) {
      return AppError(error.message, code: 'VALIDATION');
    }
    return const AppError(
      'Permintaan belum berhasil. Coba lagi atau hubungi pengelola.',
    );
  }

  @override
  String toString() => message;
}
