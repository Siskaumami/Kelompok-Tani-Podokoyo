import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tani_mobile/app/app.dart';
import 'package:tani_mobile/app/router.dart';
import 'package:tani_mobile/core/auth/auth_controller.dart';

import 'fakes.dart';

Future<void> pumpTestApp(
  WidgetTester tester,
  TestHarness harness, {
  String path = '/dashboard',
  Size size = const Size(390, 844),
  bool capture = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(
    () => harness.container.read(authProvider.notifier).restore(),
  );
  final app = UncontrolledProviderScope(
    container: harness.container,
    child: const TaniApp(restoreSession: false),
  );
  await tester.pumpWidget(
    capture ? RepaintBoundary(key: const ValueKey('capture'), child: app) : app,
  );
  harness.container.read(routerProvider).go(path);
  await tester.pumpAndSettle();
}

Future<void> finishTestApp(WidgetTester tester, TestHarness harness) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  harness.dispose();
}

Future<void> enterField(WidgetTester tester, String name, String text) async {
  final field = find.byKey(ValueKey('field.$name'));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> initializeWidgetTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final loader = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}
