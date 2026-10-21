import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_controller.dart';
import '../core/theme/tokens.dart';
import '../core/widgets/common.dart';
import '../features/reports/data/report_export.dart';
import 'providers.dart';
import 'router.dart';

class TaniApp extends ConsumerStatefulWidget {
  const TaniApp({super.key, this.restoreSession = true});
  final bool restoreSession;
  @override
  ConsumerState<TaniApp> createState() => _TaniAppState();
}

class _TaniAppState extends ConsumerState<TaniApp> with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.restoreSession) {
      unawaited(
        Future<void>.microtask(() => ref.read(authProvider.notifier).restore()),
      );
    }
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_verify()),
    );
  }

  Future<void> _verify() async {
    if (!mounted || !ref.read(authProvider).authenticated) return;
    await ref.read(authProvider.notifier).verify();
    if (mounted) ref.read(dataEpochProvider.notifier).advance();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      unawaited(_verify());
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.authenticated == true && !next.authenticated) {
        imageCache.clear();
        imageCache.clearLiveImages();
        unawaited(
          ref
              .read(reportExportProvider)
              .clearTemporaryFiles()
              .catchError((Object _) {}),
        );
      }
    });
    return MaterialApp.router(
      title: 'Kosabangsa Podokoyo',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Brand(),
                SizedBox(height: 24),
                Notice(
                  'Alamat layanan belum disiapkan. Hubungi pengelola kelompok tani.',
                  error: true,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
