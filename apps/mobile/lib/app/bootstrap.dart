import 'package:flutter/services.dart';

import '../core/theme/tokens.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../firebase_options.dart';

import '../core/config/app_config.dart';
import '../core/widgets/common.dart';
import 'app.dart';
import 'providers.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> bootstrap() async {
WidgetsFlutterBinding.ensureInitialized();

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

FirebaseMessaging.onBackgroundMessage(
  firebaseMessagingBackgroundHandler,
);

SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Tokens.workspace,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await initializeDateFormatting('id_ID');
  ErrorWidget.builder = (_) => const Padding(
    padding: EdgeInsets.all(16),
    child: Notice(
      'Tampilan belum dapat dimuat. Buka kembali halaman atau masuk ulang.',
      error: true,
    ),
  );
  try {
    final config = AppConfig.environment();
    runApp(
      ProviderScope(
        retry: (_, error) => null,
        overrides: [configProvider.overrideWithValue(config)],
        child: const TaniApp(),
      ),
    );
  } on FormatException {
    runApp(const ConfigurationErrorApp());
  }
}
