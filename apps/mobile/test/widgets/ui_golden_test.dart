import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/widget_app.dart';

void main() {
  setUpAll(initializeWidgetTests);
  final screens = [
    ('products-phone', '/dashboard/products', const Size(390, 844)),
    ('opnames-phone', '/dashboard/opnames', const Size(390, 844)),
    ('workspace-tablet', '/dashboard', const Size(1024, 768)),
    ('login-phone', '/login', const Size(390, 844)),
  ];
  for (final screen in screens) {
    testWidgets('approved UI reference ${screen.$1}', (tester) async {
      final h = TestHarness(authenticated: screen.$1 != 'login-phone');
      await pumpTestApp(
        tester,
        h,
        path: screen.$2,
        size: screen.$3,
        capture: true,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('../goldens/${screen.$1}.png'),
      );
      await finishTestApp(tester, h);
    });
  }
}
