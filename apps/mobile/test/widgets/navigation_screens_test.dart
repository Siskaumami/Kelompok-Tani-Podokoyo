import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tani_mobile/app/navigation.dart';
import 'package:tani_mobile/app/router.dart';
import 'package:tani_mobile/core/auth/auth_controller.dart';
import 'package:tani_mobile/core/widgets/forms/mutation_dialog.dart';

import '../support/fakes.dart';
import '../support/widget_app.dart';

void main() {
  setUpAll(initializeWidgetTests);
  final headings = [
    'Kelompok Tani Uji',
    'Panen & sortir',
    'Persediaan',
    'Produk, harga & HPP',
    'Rencana produksi',
    'Hasil produksi',
    'Cek stok fisik',
    'Penjualan',
    'Pembukuan & laporan',
    'Konten website',
    'Pengguna',
    'Anggota kelompok tani',
    'Riwayat aktivitas',
    'Pengaturan',
  ];
  for (final size in const [Size(320, 740), Size(1024, 768)]) {
    for (var index = 0; index < destinations.length; index++) {
      final destination = destinations[index];
      final heading = headings[index];
      testWidgets(
        '${destination.label} renders at ${size.width.toInt()} with native responsive hierarchy',
        (tester) async {
          final h = TestHarness();
          await pumpTestApp(tester, h, path: destination.path, size: size);
          expect(find.text(heading), findsAtLeastNWidgets(1));
          expect(tester.takeException(), isNull);
          if (size.width < 900) {
            expect(find.byTooltip('Buka navigasi'), findsOneWidget);
          }
          await finishTestApp(tester, h);
        },
      );
    }
  }
  testWidgets(
    'unauthenticated protected routes return to login without fetching ERP data',
    (tester) async {
      final h = TestHarness(authenticated: false);
      await pumpTestApp(tester, h, path: '/dashboard/users');
      expect(find.text('Selamat datang kembali.'), findsOneWidget);
      expect(
        h.server.adapter.requests.where((r) => r.uri.path.endsWith('/users')),
        isEmpty,
      );
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'phone navigation drawer preserves menu sequence, active route and logout access',
    (tester) async {
      final h = TestHarness();
      await pumpTestApp(tester, h);
      await tester.tap(find.byTooltip('Buka navigasi'));
      await tester.pumpAndSettle();
      expect(find.text('Ringkasan'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
      await tester.tap(find.text('Panen'));
      await tester.pumpAndSettle();
      expect(find.text('Panen & sortir'), findsOneWidget);
      await tester.tap(find.byTooltip('Buka navigasi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      expect(find.text('Selamat datang kembali.'), findsOneWidget);
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'Admin sees normal operation screens and no Owner-only controls',
    (tester) async {
      final h = TestHarness(role: 'ADMIN');
      await pumpTestApp(tester, h, path: '/dashboard/users');
      expect(find.text('Undang Admin'), findsNothing);
      expect(find.text('Jadikan Owner'), findsNothing);
      h.container.read(routerProvider).go('/dashboard/settings');
      await tester.pumpAndSettle();
      expect(find.text('Ubah pengaturan'), findsNothing);
      expect(find.text('Ganti kata sandi'), findsOneWidget);
      h.container.read(routerProvider).go('/dashboard/products');
      await tester.pumpAndSettle();
      expect(find.text('Harga & HPP Grade A'), findsOneWidget);
      expect(find.text('Ubah harga / HPP'), findsNothing);
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'Owner transfer refreshes live role and removes Owner controls immediately',
    (tester) async {
      final h = TestHarness();
      h.server.overrides['POST /users/$adminId/transfer-owner'] = (_) {
        h.server.role = 'ADMIN';
        return Reply({'owner': adminRow, 'previous_owner': userRow});
      };
      await pumpTestApp(tester, h, path: '/dashboard/users');
      await tester.ensureVisible(find.text('Jadikan Owner'));
      await tester.tap(find.text('Jadikan Owner'));
      await tester.pumpAndSettle();
      await enterField(tester, 'current_password', 'a-current-password');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Pindahkan Owner'));
      await tester.pumpAndSettle();
      expect(h.container.read(authProvider).user!.isOwner, isFalse);
      h.container.read(routerProvider).go('/dashboard/users');
      await tester.pumpAndSettle();
      expect(find.text('Undang Admin'), findsNothing);
      expect(find.text('Jadikan Owner'), findsNothing);
      expect(find.byType(MutationDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'server error and empty records have explicit states and recover via retry',
    (tester) async {
      final h = TestHarness();
      h.server.overrides['GET /harvests'] = (_) => Reply.error(
        503,
        'DATABASE_UNAVAILABLE',
        'Layanan sedang tidak tersedia.',
      );
      await pumpTestApp(tester, h, path: '/dashboard/harvests');
      expect(find.text('Layanan sedang tidak tersedia.'), findsOneWidget);
      h.server.overrides['GET /harvests'] = (_) => Reply(page([]));
      await tester.tap(find.text('Coba lagi →'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada panen & sortir'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'product actions retain two-column ordering and completed count note never resembles a button',
    (tester) async {
      final h = TestHarness();
      await pumpTestApp(tester, h, path: '/dashboard/products');
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Harga / HPP'),
      );
      await tester.pump();
      final edit = tester.getTopLeft(
        find.widgetWithText(OutlinedButton, 'Edit'),
      );
      final history = tester.getTopLeft(
        find.widgetWithText(OutlinedButton, 'Riwayat'),
      );
      final economics = tester.getTopLeft(
        find.widgetWithText(OutlinedButton, 'Harga / HPP'),
      );
      final archive = tester.getTopLeft(
        find.widgetWithText(OutlinedButton, 'Nonaktifkan'),
      );
      expect(edit.dy, history.dy);
      expect(economics.dy, archive.dy);
      expect(edit.dy, lessThan(economics.dy));
      expect(edit.dx, lessThan(history.dx));
      h.server.overrides['GET /opnames'] = (_) => Reply(
        page([
          {
            ...opname,
            'status': 'COMPLETED',
            'physical_quantity': '1000000',
            'difference': '0',
          },
        ]),
      );
      h.container.read(routerProvider).go('/dashboard/opnames');
      await tester.pumpAndSettle();
      expect(find.text('Sesuai'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Sesuai'),
          matching: find.byType(OutlinedButton),
        ),
        findsNothing,
      );
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'sale detail renders historical snapshots and server totals unchanged',
    (tester) async {
      final h = TestHarness();
      await pumpTestApp(tester, h, path: '/dashboard/sales');
      await tester.ensureVisible(find.text('Rincian'));
      await tester.tap(find.text('Rincian'));
      await tester.pumpAndSettle();
      expect(find.text('Keripik Kentang Lama'), findsOneWidget);
      expect(find.text('Rp11.500 per kg'), findsOneWidget);
      expect(find.text('Rp16.500'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
      await finishTestApp(tester, h);
    },
  );
}
