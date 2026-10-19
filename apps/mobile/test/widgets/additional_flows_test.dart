import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tani_mobile/app/router.dart';

import '../support/fakes.dart';
import '../support/widget_app.dart';

Future<void> selectChoice(WidgetTester tester, int index, String text) async {
  final field = find.byType(DropdownButtonFormField<String>).at(index);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Finder labeledTextField(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
void main() {
  setUpAll(initializeWidgetTests);
  testWidgets(
    'marketplace sale posts Grade A and finished lines, actual price, discount and fee without local totals',
    (tester) async {
      final h = TestHarness();
      await pumpTestApp(tester, h, path: '/dashboard/sales');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Catat penjualan'));
      await tester.pumpAndSettle();
      await selectChoice(tester, 0, 'Shopee');
      await enterField(tester, 'discount_rp', '500');
      await enterField(tester, 'fee_rp', '1000');
      await selectChoice(tester, 1, 'Kentang Grade A');
      await tester.ensureVisible(labeledTextField('Jumlah (kg)'));
      await tester.enterText(labeledTextField('Jumlah (kg)'), '1,5');
      await tester.ensureVisible(labeledTextField('Harga per kg (Rp)'));
      await tester.enterText(labeledTextField('Harga per kg (Rp)'), '12500');
      await tester.ensureVisible(find.text('Tambah barang'));
      await tester.tap(find.text('Tambah barang'));
      await tester.pumpAndSettle();
      await selectChoice(tester, 2, 'Keripik Kentang');
      await tester.ensureVisible(labeledTextField('Jumlah (unit)'));
      await tester.enterText(labeledTextField('Jumlah (unit)'), '2');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();
      final body = bodyOf(
        h.server.adapter.requests.singleWhere(
          (r) => r.method == 'POST' && r.uri.path.endsWith('/sales'),
        ),
      );
      expect(body['channel'], 'SHOPEE');
      expect(body['discount_rp'], '500');
      expect(body['fee_rp'], '1000');
      expect(body['items'], [
        {'item_id': gradeAId, 'quantity': '1500', 'unit_price_rp': '12500'},
        {'item_id': finishedId, 'quantity': '2'},
      ]);
      expect(body.containsKey('hpp_rp'), isFalse);
      expect(body.containsKey('net_rp'), isFalse);
      expect(tester.takeException(), isNull);
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'daily confirmation acknowledges reminder without closing bookkeeping',
    (tester) async {
      final h = TestHarness();
      await pumpTestApp(tester, h, path: '/dashboard/sales');
      await tester.tap(find.text('Selesai mencatat'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Pengingat tanggal ini dihentikan. Ini bukan penutupan buku.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Konfirmasi pencatatan'),
      );
      await tester.pumpAndSettle();
      final request = h.server.adapter.requests.singleWhere(
        (r) => r.uri.path.endsWith('/sales-day/confirm'),
      );
      expect(bodyOf(request), {'business_date': today, 'status': 'COMPLETED'});
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'password change uses existing auth endpoint then removes the session and returns to login',
    (tester) async {
      final h = TestHarness();
      await pumpTestApp(tester, h, path: '/dashboard/settings');
      await tester.ensureVisible(find.text('Ganti kata sandi'));
      await tester.tap(find.text('Ganti kata sandi'));
      await tester.pumpAndSettle();
      await enterField(tester, 'current_password', 'Current-test-password');
      await enterField(tester, 'password', 'New-test-password-128');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Selamat datang kembali.'), findsOneWidget);
      expect(h.store.cookie, isNull);
      expect(
        bodyOf(
          h.server.adapter.requests.firstWhere(
            (r) => r.uri.path.endsWith('/change-password'),
          ),
        ),
        {
          'current_password': 'Current-test-password',
          'password': 'New-test-password-128',
        },
      );
      await finishTestApp(tester, h);
    },
  );

  testWidgets(
    'account deletion is blocked for Owner and removes an Admin session after confirmation',
    (tester) async {
      final ownerHarness = TestHarness();

      await pumpTestApp(
        tester,
        ownerHarness,
        path: '/dashboard/settings',
      );

      await tester.ensureVisible(
        find.text(
          'Untuk menghapus akun Pengelola Utama, pindahkan peran Pengelola Utama ke Admin lain terlebih dahulu.',
        ),
      );

      expect(
        find.text(
          'Untuk menghapus akun Pengelola Utama, pindahkan peran Pengelola Utama ke Admin lain terlebih dahulu.',
        ),
        findsOneWidget,
      );

      expect(
        find.widgetWithText(OutlinedButton, 'Hapus akun'),
        findsNothing,
      );

      await finishTestApp(tester, ownerHarness);

      final adminHarness = TestHarness(role: 'ADMIN');

      await pumpTestApp(
        tester,
        adminHarness,
        path: '/dashboard/settings',
      );

      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Hapus akun'),
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Hapus akun'),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hapus akun'), findsWidgets);

      await enterField(
        tester,
        'current_password',
        'Current-test-password',
      );

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Hapus akun'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Selamat datang kembali.'),
        findsOneWidget,
      );

      expect(adminHarness.store.cookie, isNull);

      final request = adminHarness.server.adapter.requests.singleWhere(
        (r) =>
            r.method == 'POST' &&
            r.uri.path.endsWith('/auth/delete-account'),
      );

      expect(
        bodyOf(request),
        {
          'current_password': 'Current-test-password',
        },
      );

      expect(tester.takeException(), isNull);

      await finishTestApp(tester, adminHarness);
    },
  );
  testWidgets(
    'audit detail preserves before/after information and hides identifier/secret fields',
    (tester) async {
      final h = TestHarness();
      h.server.overrides['GET /audit'] = (_) => Reply(
        page([
          {
            ...audit,
            'before_data': {
              'name': 'Sebelumnya',
              'id': recordId,
              'password_hash': 'must-not-render',
            },
            'after_data': {'name': 'Sesudahnya', 'id': recordId},
          },
        ]),
      );
      await pumpTestApp(tester, h, path: '/dashboard/audit');
      await tester.ensureVisible(find.text('Lihat perubahan'));
      await tester.tap(find.text('Lihat perubahan'));
      await tester.pumpAndSettle();
      expect(find.text('Sebelum'), findsOneWidget);
      expect(find.text('Sesudah'), findsOneWidget);
      expect(find.text('Sebelumnya'), findsOneWidget);
      expect(find.text('Sesudahnya'), findsOneWidget);
      expect(find.text('must-not-render'), findsNothing);
      await finishTestApp(tester, h);
    },
  );
  testWidgets('empty report and negative server profit stay truthful', (
    tester,
  ) async {
    final h = TestHarness();
    h.server.overrides['GET /reports'] = (_) => Reply({
      ...report,
      'transactions': [],
      'totals': {
        for (final key in (report['totals'] as Map).keys)
          key: key == 'sale_count' || key == 'voided_count'
              ? 0
              : key == 'profit_rp'
              ? '-999'
              : '0',
      },
    });
    await pumpTestApp(tester, h, path: '/dashboard/reports');
    expect(find.text('Rp-999'), findsOneWidget);
    await tester.ensureVisible(
      find.text('Tidak ada penjualan dalam periode ini'),
    );
    expect(find.text('Tidak ada penjualan dalam periode ini'), findsOneWidget);
    await finishTestApp(tester, h);
  });
  testWidgets(
    'large system text keeps small-phone headings, role context and forms usable',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = TestHarness();
      await pumpTestApp(
        tester,
        h,
        path: '/dashboard/products',
        size: const Size(320, 740),
      );
      expect(tester.takeException(), isNull);
      h.container.read(routerProvider).go('/dashboard/harvests');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Catat panen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'expired session during a save exits the dialog without a reload loop',
    (tester) async {
      final h = TestHarness();
      h.server.overrides['POST /harvests'] = (_) =>
          Reply.error(401, 'AUTH_REQUIRED', 'Silakan masuk untuk melanjutkan.');
      await pumpTestApp(tester, h, path: '/dashboard/harvests');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Catat panen'));
      await tester.pumpAndSettle();
      await enterField(tester, 'total_g', '10');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Selamat datang kembali.'), findsOneWidget);
      expect(h.store.cookie, isNull);
      expect(h.server.adapter.requests.length, lessThan(12));
      expect(tester.takeException(), isNull);
      await finishTestApp(tester, h);
    },
  );
}
