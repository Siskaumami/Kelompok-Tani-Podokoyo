import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tani_mobile/core/config/app_config.dart';
import 'package:tani_mobile/core/errors/app_error.dart';
import 'package:tani_mobile/core/network/json_data.dart';
import 'package:tani_mobile/core/network/mutation.dart';
import 'package:tani_mobile/core/storage/session_store.dart';
import 'package:tani_mobile/core/utils/format.dart';
import 'package:tani_mobile/features/auth/data/auth_link.dart';
import 'package:tani_mobile/features/reports/data/report_export.dart';
import 'package:tani_mobile/features/reports/data/report_data.dart';

import '../../tool/release_preflight.dart' as release;
import '../support/fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  group('Exact quantities and presentation', () {
    test('kg conversion is integer-exact including three decimals and large values', () {
      expect(grams('1000000000,001'), '1000000000001');
      expect(grams('0,001'), '1');
      expect(grams(' 15,05 '), '15050');
      expect(grams('1.5'), '1500');
      expect(kgInput('15050'), '15,05');
      expect(integerInput('1000000000000'), '1000000000000');
    });
    for (final invalid in [
      '1.000',
      '1,0001',
      '-1',
      '1e3',
      '',
      ',5',
      '1,',
    ]) {
      test(
        'rejects ambiguous kg input "$invalid"',
        () => expect(() => grams(invalid), throwsFormatException),
      );
    }
    test('integer domain limits, zero, and positive constraints', () {
      for (final invalid in ['01', '-1', '1.000', '1000000000001', '1e3']) {
        expect(() => integerInput(invalid), throwsFormatException);
      }
      expect(integerInput('0'), '0');
      expect(() => integerInput('0', positive: true), throwsFormatException);
    });
    test('money/grams never pass through double and keep negative sub-kilogram sign', () {
      expect(money('9007199254740993000'), 'Rp9.007.199.254.740.993.000');
      expect(quantity('-1', 'GRADE_A'), '-0,001 kg');
      expect(quantity('-1200500', 'GRADE_B'), '-1.200,5 kg');
      expect(quantity('120', 'FINISHED'), '120 unit');
    });
    test('calendar dates and approved statuses', () {
      expect(() => validDate('2026-02-30'), throwsFormatException);
      expect(validDate('2024-02-29'), '2024-02-29');
      expect(shortDate(today), '17 Okt 2026');
      expect(statusNames['OWNER'], 'Pengelola Utama');
      expect(
        reasonLabel('OTHER: catatan: tambahan'),
        'Lainnya: catatan: tambahan',
      );
    });
    test('WhatsApp matches the web conversion', () {
      expect(whatsappUrl('0812 3456 7890'), 'https://wa.me/6281234567890');
      expect(whatsappNumber('https://wa.me/6281234567890'), '081234567890');
      expect(whatsappUrl(''), '');
    });
  });
  group('Configuration and release gates', () {
    test(
      'normalizes only the existing API prefix and separate exact APP origin',
      () {
        final config = AppConfig.parse(
          'https://api.example.test/api/v1/',
          origin: 'https://app.example.test/',
        );
        expect(config.apiBase, 'https://api.example.test/api/v1');
        expect(config.appOrigin, 'https://app.example.test');
        expect(
          config.apiUri('/auth/me').toString(),
          'https://api.example.test/api/v1/auth/me',
        );
      },
    );
    for (final invalid in [
      '',
      'localhost',
      'https://a.test/other',
      'https://user:password@a.test',
      'https://a.test?q=1',
      'https://a.test#token',
    ]) {
      test(
        'rejects invalid configuration $invalid',
        () => expect(() => AppConfig.parse(invalid), throwsFormatException),
      );
    }
    test(
      'release forbids HTTP while explicitly configured debug HTTP works',
      () {
        expect(
          () => AppConfig.parse('http://dev.example.test', release: true),
          throwsFormatException,
        );
        expect(
          AppConfig.parse(
            'http://dev.example.test',
            release: false,
          ).server.scheme,
          'http',
        );
        expect(
          () => AppConfig.parse(
            'https://api.example.test',
            origin: 'http://app.example.test',
            release: true,
          ),
          throwsFormatException,
        );
        expect(
          () => release.verifyReleaseValues({
            'API_BASE_URL': 'http://example.test',
          }),
          throwsFormatException,
        );
        expect(
          () => release.verifyReleaseValues({
            'API_BASE_URL': 'https://example.test',
          }),
          returnsNormally,
        );
      },
    );
    test(
      'rejects escaping API paths and credential exfiltration destinations',
      () {
        final config = AppConfig.parse('https://api.example.test');
        for (final invalid in [
          'https://evil.example/me',
          '//evil.example/me',
          '/../public',
          '/x#token',
        ]) {
          expect(() => config.apiUri(invalid), throwsFormatException);
        }
      },
    );
  });
  group('Parsers and exported files', () {
    test('malformed shapes and decimal money are rejected', () {
      expect(() => RecordData([]), throwsA(isA<AppError>()));
      expect(
        () => RecordData({'balance': 1.5}).number('balance'),
        throwsA(isA<AppError>()),
      );
      expect(
        () => RecordData({'balance': '1e9'}).number('balance'),
        throwsA(isA<AppError>()),
      );
      expect(
        () => RecordPage.parse({'items': [], 'next_offset': '30'}, paged: true),
        throwsA(isA<AppError>()),
      );
      expect(
        () => RecordPage.parse({'items': {}, 'next_offset': null}, paged: true),
        throwsA(isA<AppError>()),
      );
      expect(RecordPage.parse(page([], next: 30), paged: true).nextOffset, 30);
    });
    test('secure session serialization redacts diagnostics and rejects arbitrary cookies', () {
      final cookie = SessionCookie(
        '__Host-tani_session',
        fakeToken,
        DateTime.now().add(const Duration(hours: 1)),
      );
      expect(SessionCookie.decode(cookie.encode()).value, fakeToken);
      expect(cookie.toString(), isNot(contains(fakeToken)));
      expect(
        () => SessionCookie.decode(
          jsonEncode({
            'name': 'unrelated',
            'value': fakeToken,
            'expires': '2027-01-01',
          }),
        ),
        throwsFormatException,
      );
    });
    test(
      'pending mutation captures exact payload and valid cryptographic UUID v4',
      () {
        final payload = <String, Object?>{
          'items': [
            {'quantity': '7'},
          ],
        };
        final mutation = PendingMutation(
          path: '/sales',
          method: 'POST',
          payload: payload,
        );
        (payload['items'] as List)[0]['quantity'] = '99';
        expect((mutation.payload['items'] as List)[0]['quantity'], '7');
        expect(
          mutation.key,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(List.generate(100, (_) => uuidV4()).toSet().length, 100);
      },
    );
    test('PDF bytes must be nonempty actual PDF and filenames cannot traverse directories', () {
      expect(
        decodeReportPdf(
          RecordData({'content_base64': base64Encode(utf8.encode('%PDF-1.4'))}),
        ).length,
        8,
      );
      for (final data in [
        {'content_base64': ''},
        {'content_base64': 'not_base64'},
        {
          'content_base64': base64Encode([1, 2, 3]),
        },
      ]) {
        expect(
          () => decodeReportPdf(RecordData(data)),
          throwsA(isA<AppError>()),
        );
      }
      expect(
        safeReportFilename('laporan-$today-$today.pdf'),
        'laporan-$today-$today.pdf',
      );
      expect(
        () => safeReportFilename('../../private.pdf'),
        throwsA(isA<AppError>()),
      );
    });
    test('report enforces server-supported periods and accepts negative profit from server', () {
      expect(
        () => validatePeriod('2026-10-17', '2026-10-16'),
        throwsA(isA<AppError>()),
      );
      expect(
        () => validatePeriod('2025-01-01', '2026-12-31'),
        throwsA(isA<AppError>()),
      );
      final data = report;
      (data['totals'] as Map)['profit_rp'] = '-999';
      expect(ReportData(data).totals.number('profit_rp'), '-999');
    });
    test('email fragment links and direct tokens are recognized without foreign origin acceptance', () {
      final config = AppConfig.parse(
        'https://api.example.test',
        origin: 'https://app.example.test',
      );
      expect(
        tokenFromLink(
          'https://app.example.test/accept-invitation#token=$fakeToken',
          config,
          '/accept-invitation',
        ),
        fakeToken,
      );
      expect(tokenFromLink(fakeToken, config, '/reset-password'), fakeToken);
      for (final link in [
        'https://evil.example/accept-invitation#token=$fakeToken',
        'https://app.example.test/accept-invitation?token=$fakeToken',
      ]) {
        expect(
          () => tokenFromLink(link, config, '/accept-invitation'),
          throwsFormatException,
        );
      }
    });
  });
}
