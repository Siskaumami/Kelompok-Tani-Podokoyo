import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tani_mobile/core/widgets/forms/mutation_dialog.dart';

import '../support/fakes.dart';
import '../support/widget_app.dart';

Future<void> openHarvest(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Catat panen'));
  await tester.pumpAndSettle();
  await enterField(tester, 'total_g', '10');
  await enterField(tester, 'grade_a_g', '7');
  await enterField(tester, 'grade_b_g', '3');
}

void main() {
  setUpAll(initializeWidgetTests);
  testWidgets(
    'harvest form uses decimal kg, optional grades, and no backend write while typing',
    (tester) async {
      final h = TestHarness();
      await pumpTestApp(tester, h, path: '/dashboard/harvests');
      await openHarvest(tester);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('field.total_g')),
                matching: find.byType(TextField),
              ),
            )
            .keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      expect(
        h.server.adapter.requests.where((r) => r.method != 'GET'),
        isEmpty,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();
      final request = h.server.adapter.requests.singleWhere(
        (r) => r.method == 'POST' && r.uri.path.endsWith('/harvests'),
      );
      expect(bodyOf(request)['total_g'], '10000');
      expect(bodyOf(request)['reject_g'], '0');
      expect(find.byType(MutationDialog), findsNothing);
      await finishTestApp(tester, h);
    },
  );
  testWidgets('failed validation retains editable input and sends no write', (
    tester,
  ) async {
    final h = TestHarness();
    await pumpTestApp(tester, h, path: '/dashboard/harvests');
    await openHarvest(tester);
    await enterField(tester, 'grade_a_g', '11');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(
      find.text('Jumlah hasil sortir melebihi total panen.'),
      findsOneWidget,
    );
    expect(h.server.adapter.requests.where((r) => r.method == 'POST'), isEmpty);
    await finishTestApp(tester, h);
  });
  testWidgets(
    'uncertain save locks fields and manual retry preserves the original UUID and payload',
    (tester) async {
      final h = TestHarness();
      var count = 0;
      h.server.overrides['POST /harvests'] = (r) {
        if (count++ == 0) {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionError,
          );
        }
        return const Reply({'id': recordId});
      };
      await pumpTestApp(tester, h, path: '/dashboard/harvests');
      await openHarvest(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(count, 1);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('field.total_g')))
            .enabled,
        isFalse,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Coba lagi'));
      await tester.pumpAndSettle();
      final requests = h.server.adapter.requests
          .where((r) => r.method == 'POST' && r.uri.path.endsWith('/harvests'))
          .toList();
      expect(count, 2);
      expect(requests[0].data, requests[1].data);
      expect(
        requests[0].headers['Idempotency-Key'],
        requests[1].headers['Idempotency-Key'],
      );
      expect(find.byType(MutationDialog), findsNothing);
      await finishTestApp(tester, h);
    },
  );
  testWidgets('matching physical count disables reason and submits null', (
    tester,
  ) async {
    final h = TestHarness();
    await pumpTestApp(tester, h, path: '/dashboard/opnames');
    await tester.ensureVisible(find.text('Isi hasil hitung'));
    await tester.tap(find.text('Isi hasil hitung'));
    await tester.pumpAndSettle();
    await enterField(tester, 'physical_quantity', '1000');
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.onChanged, isNull);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pumpAndSettle();
    final request = h.server.adapter.requests.singleWhere(
      (r) => r.uri.path.endsWith('/complete'),
    );
    expect(bodyOf(request), {
      'physical_quantity': '1000000',
      'reason': null,
      'notes': '',
    });
    await finishTestApp(tester, h);
  });
  testWidgets(
    'different physical count requires reason at submit with no realtime mutation',
    (tester) async {
      final h = TestHarness();
      await pumpTestApp(tester, h, path: '/dashboard/opnames');
      await tester.ensureVisible(find.text('Isi hasil hitung'));
      await tester.tap(find.text('Isi hasil hitung'));
      await tester.pumpAndSettle();
      await enterField(tester, 'physical_quantity', '999');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pilih alasan selisih sebelum menyimpan.'),
        findsOneWidget,
      );
      expect(
        h.server.adapter.requests.where((r) => r.method == 'POST'),
        isEmpty,
      );
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Susut / rusak').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(
        bodyOf(
          h.server.adapter.requests.firstWhere((r) => r.method == 'POST'),
        )['reason'],
        'SHRINKAGE_OR_DAMAGE',
      );
      await finishTestApp(tester, h);
    },
  );
  testWidgets(
    'stale stock requires explicit refresh confirmation and never retries completion automatically',
    (tester) async {
      final h = TestHarness();
      h.server.overrides['POST /opnames/$recordId/complete'] = (_) =>
          Reply.error(
            409,
            'STALE_BASELINE',
            'Stok berubah selama pemeriksaan. Gunakan stok terbaru dan hitung ulang sebelum menyimpan.',
          );
      await pumpTestApp(tester, h, path: '/dashboard/opnames');
      await tester.ensureVisible(find.text('Isi hasil hitung'));
      await tester.tap(find.text('Isi hasil hitung'));
      await tester.pumpAndSettle();
      await enterField(tester, 'physical_quantity', '1000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(
        h.server.adapter.requests.where((r) => r.uri.path.endsWith('/refresh')),
        isEmpty,
      );
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Gunakan stok terbaru').last,
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Gunakan stok terbaru').last,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Stok tercatat akan diperbarui. Setelah itu, hitung kembali jumlah barang yang ada.',
        ),
        findsOneWidget,
      );
      expect(
        h.server.adapter.requests.where((r) => r.uri.path.endsWith('/refresh')),
        isEmpty,
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Gunakan stok terbaru'),
      );
      await tester.pumpAndSettle();
      expect(
        h.server.adapter.requests
            .where((r) => r.uri.path.endsWith('/refresh'))
            .length,
        1,
      );
      expect(
        h.server.adapter.requests
            .where((r) => r.uri.path.endsWith('/complete'))
            .length,
        1,
      );
      expect(find.byType(MutationDialog), findsNothing);
      await finishTestApp(tester, h);
    },
  );
}
