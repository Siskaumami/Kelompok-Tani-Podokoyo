import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tani_mobile/core/config/app_config.dart';
import 'package:tani_mobile/core/errors/app_error.dart';
import 'package:tani_mobile/core/network/api_client.dart';
import 'package:tani_mobile/core/network/json_data.dart';
import 'package:tani_mobile/features/reports/data/report_export.dart';

import '../support/fakes.dart';

import 'package:tani_mobile/core/auth/auth_controller.dart';

class BinaryAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromBytes(
      [82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80, 0],
      200,
      headers: {
        'content-type': ['image/webp'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('nested response data is immutable and independent from editable form copies', () {
    final record = RecordData({
      'items': [
        {'notes': 'original'},
      ],
    });
    final copy = record.json;
    (copy['items'] as List)[0]['notes'] = 'changed';
    expect(record.rows('items').single.s('notes'), 'original');
    expect(() => (record['items'] as List).add({}), throwsUnsupportedError);
    expect(
      () => RecordData({'id': 'malformed/path'}),
      throwsA(isA<AppError>()),
    );
  });
  test('signed Filebase image retrieval carries no session, CSRF, Origin or idempotency key', () async {
    final store = MemorySessionStore(authenticated: true);
    final auth = FakeAdapter(
      (_) => const Reply(
        null,
        status: 302,
        headers: {
          'location': [
            'https://images.s3.filebase.io/photo.webp?signature=fixture',
          ],
        },
      ),
    );
    final bytes = BinaryAdapter();
    final authorized = Dio()..httpClientAdapter = auth;
    final api = ApiClient(
      AppConfig.parse('https://api.example.test'),
      store,
      dio: authorized,
      anonymousClient: () => Dio()..httpClientAdapter = bytes,
    );
    await api.restoreCookie();
    api.setCsrf(fakeCsrf);
    await api.image(recordId);
    expect(auth.requests.single.headers['Cookie'], contains(fakeToken));
    final headers = bytes.requests.single.headers.keys.map(
      (v) => v.toLowerCase(),
    );
    expect(headers, isNot(contains('cookie')));
    expect(headers, isNot(contains('x-csrf-token')));
    expect(headers, isNot(contains('origin')));
    expect(headers, isNot(contains('idempotency-key')));
    api.close();
  });
  test('unexpected image redirect destinations are rejected before any anonymous request', () async {
    for (final destination in [
      'http://images.s3.filebase.io/photo.webp',
      'https://unrelated.example/photo.webp',
      'https://user:pass@images.s3.filebase.io/photo.webp',
    ]) {
      final dio = Dio()
        ..httpClientAdapter = FakeAdapter(
          (_) => Reply(
            null,
            status: 302,
            headers: {
              'location': [destination],
            },
          ),
        );
      final api = ApiClient(
        AppConfig.parse('https://api.example.test'),
        MemorySessionStore(authenticated: true),
        dio: dio,
      );
      await api.restoreCookie();
      await expectLater(api.image(recordId), throwsA(isA<AppError>()));
      api.close();
    }
  });
  test('PDF export uses private temporary directories, safe filename and native share boundary', () async {
    final h = TestHarness();
    await h.container.read(authProvider.notifier).restore();
    final temp = await Directory('build').createTemp('pdf-test-');
    try {
      File? shared;
      final exporter = ReportExport(
        h.api,
        temporaryDirectory: () async => temp,
        shareFile: (file, position) async {
          shared = file;
        },
      );
      await exporter.share(today, today, const Rect.fromLTWH(1, 1, 20, 20));
      expect(shared, isNotNull);
      expect(shared!.path.startsWith(temp.path), isTrue);
      expect(
        String.fromCharCodes((await shared!.readAsBytes()).take(5)),
        '%PDF-',
      );
      expect(
        h.server.adapter.requests.last.headers['Accept'],
        'application/json',
      );
      await exporter.clearTemporaryFiles();
      expect(await shared!.exists(), isFalse);
    } finally {
      await temp.delete(recursive: true);
      h.dispose();
    }
  });
}
