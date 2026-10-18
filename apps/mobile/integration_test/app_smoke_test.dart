import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tani_mobile/app/app.dart';
import 'package:tani_mobile/app/router.dart';
import 'package:tani_mobile/core/auth/auth_controller.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native login and protected ERP navigation with isolated HTTP fixture',
    (tester) async {
      await initializeDateFormatting('id_ID');
      final harness = TestHarness(authenticated: false);
      await harness.container.read(authProvider.notifier).restore();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const TaniApp(restoreSession: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'owner@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'An-isolated-test-password',
      );
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Masuk →'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk →'));
      await tester.pumpAndSettle();
      expect(find.text('Kelompok Tani Uji'), findsOneWidget);
      harness.container.read(routerProvider).go('/dashboard/opnames');
      await tester.pumpAndSettle();
      expect(find.text('Cek stok fisik'), findsOneWidget);
      expect(find.text('Isi hasil hitung'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      harness.dispose();
    },
  );
}
