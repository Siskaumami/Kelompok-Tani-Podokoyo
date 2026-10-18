import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_data.dart';
import '../../../core/network/mutation.dart';
import 'report_data.dart';

Uint8List decodeReportPdf(RecordData data) {
  final text = data.s('content_base64');
  if (text.isEmpty || text.length > 70 * 1024 * 1024) {
    throw const AppError(
      'File laporan kosong atau terlalu besar. Pilih periode lebih singkat.',
    );
  }
  Uint8List bytes;
  try {
    bytes = base64Decode(text);
  } on FormatException {
    throw AppError.malformed();
  }
  if (bytes.length < 5 ||
      String.fromCharCodes(bytes.sublist(0, 5)) != '%PDF-') {
    throw const AppError('File laporan belum dapat dibaca. Silakan coba lagi.');
  }
  return bytes;
}

Future<Uint8List> decodeReportPdfOffMain(RecordData data) async {
  final text = data.s('content_base64');

  if (text.isEmpty || text.length > 70 * 1024 * 1024) {
    throw const AppError(
      'File laporan kosong atau terlalu besar. Pilih periode lebih singkat.',
    );
  }

  try {
    final bytes = await Isolate.run(() => base64Decode(text));

    if (bytes.length < 5 ||
        String.fromCharCodes(bytes.sublist(0, 5)) != '%PDF-') {
      throw const AppError(
        'File laporan belum dapat dibaca. Silakan coba lagi.',
      );
    }

    return bytes;
  } on FormatException {
    throw AppError.malformed();
  }
}

String safeReportFilename(String filename) {
  if (!RegExp(r'^laporan-\d{4}-\d{2}-\d{2}-\d{4}-\d{2}-\d{2}\.pdf$')
      .hasMatch(filename)) {
    throw AppError.malformed();
  }
  return filename;
}

class ReportExport {
  ReportExport(
    this.api, {
    Future<Directory> Function()? temporaryDirectory,
    this._shareFile,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function(File, Rect)? _shareFile;
  final ApiClient api;
  Future<File> create(String from, String to) async {
    validatePeriod(from, to);
    final data = RecordData(await api.get('/reports/pdf?from=$from&to=$to'));
    final bytes = await decodeReportPdfOffMain(data);
    final filename = safeReportFilename(data.s('filename'));
    final root = Directory(
      '${(await _temporaryDirectory()).path}/tani-reports',
    );
    await root.create(recursive: true);
    await for (final file in root.list()) {
      final modified = (await file.stat()).modified;
      if (DateTime.now().difference(modified) > const Duration(hours: 1)) {
        await file.delete(recursive: true);
      }
    }
    final folder = await Directory('${root.path}/${uuidV4()}').create();
    return File('${folder.path}/$filename').writeAsBytes(bytes, flush: true);
  }

  Future<void> share(String from, String to, Rect position) async {
    final file = await create(from, to);
    if (_shareFile != null) {
      await _shareFile(file, position);
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Laporan penjualan',
        files: [XFile(file.path, mimeType: 'application/pdf')],
        sharePositionOrigin: position,
      ),
    );
  }

  Future<void> clearTemporaryFiles() async {
    final folder = Directory(
      '${(await _temporaryDirectory()).path}/tani-reports',
    );
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}

final reportExportProvider = Provider<ReportExport>(
  (ref) => ReportExport(ref.watch(apiProvider)),
);
