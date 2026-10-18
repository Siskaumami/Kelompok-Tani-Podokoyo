import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tani_mobile/app/router.dart';

import '../support/fakes.dart';
import '../support/widget_app.dart';

void main() {
  setUpAll(initializeWidgetTests);
  testWidgets(
    'valid and invalid login show correct states without storing password',
    (tester) async {
      final h = TestHarness(authenticated: false);
      h.server.overrides['POST /auth/login'] = (_) => Reply.error(
        401,
        'INVALID_CREDENTIALS',
        'Email atau kata sandi tidak sesuai.',
      );
      await pumpTestApp(tester, h, path: '/login');
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'owner@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'a-password-for-testing',
      );
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Masuk →'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk →'));
      await tester.pumpAndSettle();
      expect(find.text('Email atau kata sandi tidak sesuai.'), findsOneWidget);
      expect(h.store.cookie, isNull);
      h.server.overrides.clear();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk →'));
      await tester.pumpAndSettle();
      expect(find.text('Kelompok Tani Uji'), findsOneWidget);
      expect(h.store.cookie, isNotNull);
      expect(tester.takeException(), isNull);
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'invitation success transitions to a fresh normal login form, then Admin workspace',
    (tester) async {
      final h = TestHarness(authenticated: false, role: 'ADMIN');
      await pumpTestApp(tester, h, path: '/accept-invitation#token=$fakeToken');
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Admin undangan',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'A-new-invitation-password',
      );
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Aktifkan akun →'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Aktifkan akun →'));
      await tester.pumpAndSettle();
      expect(find.text('Akun Admin aktif. Silakan masuk.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      final body = bodyOf(h.server.adapter.requests.last);
      expect(body.keys, unorderedEquals(['token', 'password', 'name']));
      await tester.tap(find.widgetWithText(TextButton, 'Ke halaman masuk →'));
      await tester.pumpAndSettle();
      expect(find.text('Selamat datang kembali.'), findsOneWidget);
      expect(find.text('Akun Admin aktif. Silakan masuk.'), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'admin@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'A-new-invitation-password',
      );
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Masuk →'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk →'));
      await tester.pumpAndSettle();
      expect(find.text('Kelompok Tani Uji'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'expired invitation shows server explanation and allows returning to login',
    (tester) async {
      final h = TestHarness(authenticated: false);
      h.server.overrides['POST /auth/accept-invitation'] = (_) => Reply.error(
        404,
        'NOT_FOUND',
        'Undangan tidak valid atau sudah kedaluwarsa.',
      );
      await pumpTestApp(tester, h, path: '/accept-invitation#token=$fakeToken');
      await tester.enterText(find.byType(TextFormField).at(0), 'Admin');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'A-password-minimum-12',
      );
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Aktifkan akun →'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Aktifkan akun →'));
      await tester.pumpAndSettle();
      expect(
        find.text('Undangan tidak valid atau sudah kedaluwarsa.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Kembali ke halaman masuk'));
      await tester.tap(find.text('Kembali ke halaman masuk'));
      await tester.pumpAndSettle();
      expect(find.text('Selamat datang kembali.'), findsOneWidget);
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'forgot and reset password preserve existing public auth contracts',
    (tester) async {
      final h = TestHarness(authenticated: false);
      await pumpTestApp(tester, h, path: '/forgot-password');
      await tester.enterText(find.byType(TextFormField), 'owner@example.test');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Kirim tautan →'));
      await tester.pumpAndSettle();
      expect(find.text('Permintaan pemulihan diterima.'), findsOneWidget);
      expect(bodyOf(h.server.adapter.requests.last), {
        'email': 'owner@example.test',
      });
      h.container.read(routerProvider).go('/reset-password#token=$fakeToken');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'A-new-reset-password',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Perbarui kata sandi →'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Kata sandi diperbarui. Silakan masuk kembali.'),
        findsOneWidget,
      );
      expect(bodyOf(h.server.adapter.requests.last), {
        'token': fakeToken,
        'password': 'A-new-reset-password',
      });
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'missing link can be pasted without manual token extraction and password minimum is enforced',
    (tester) async {
      final h = TestHarness(authenticated: false);
      await pumpTestApp(tester, h, path: '/accept-invitation');
      await tester.enterText(find.byType(TextFormField).at(0), 'Admin uji');
      await tester.enterText(find.byType(TextFormField).at(1), 'short');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'https://app.example.test/accept-invitation#token=$fakeToken',
      );
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Aktifkan akun →'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Aktifkan akun →'));
      await tester.pumpAndSettle();
      expect(find.text('Kata sandi minimal 12 karakter.'), findsOneWidget);
      expect(h.server.adapter.requests, isEmpty);
      await finishTestApp(tester, h);
    },
  );
}
