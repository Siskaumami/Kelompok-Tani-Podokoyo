import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/session.dart';
import '../core/widgets/common.dart';
import '../core/widgets/feature_screen.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/registry.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/website_content/presentation/content_page.dart';
import 'workspace_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, state) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/dashboard',
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      final protected = path.startsWith('/dashboard');
      if (protected && !auth.authenticated) {
        if (auth.status == AuthStatus.restoring ||
            auth.status == AuthStatus.unavailable) {
          return '/loading';
        }
        return '/login';
      }
      if (path == '/loading' && auth.authenticated) return '/dashboard';
      if (path == '/loading' && auth.status == AuthStatus.signedOut) {
        return '/login';
      }
      if (path == '/login' && auth.authenticated) return '/dashboard';
      if (path == '/') return auth.authenticated ? '/dashboard' : '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, state) => const Loading()),
      GoRoute(
        path: '/loading',
        builder: (_, state) => const SessionLoadingPage(),
      ),
      for (final pair in const [
        ('/login', AuthMode.login),
        ('/forgot-password', AuthMode.forgot),
        ('/reset-password', AuthMode.reset),
        ('/accept-invitation', AuthMode.invite),
      ])
        GoRoute(
          path: pair.$1,
          builder: (_, state) => AuthPage(
            key: ValueKey(pair.$1),
            mode: pair.$2,
            token: state.uri.fragment.isEmpty
                ? ''
                : Uri.splitQueryString(state.uri.fragment)['token'] ?? '',
          ),
        ),
      ShellRoute(
        builder: (context, state, child) =>
            WorkspaceShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, state) => const DashboardPage(),
          ),
          for (final id in features.keys)
            GoRoute(
              path: '/dashboard/$id',
              builder: (_, state) => FeatureScreen(id, key: ValueKey(id)),
            ),
          GoRoute(
            path: '/dashboard/reports',
            builder: (_, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/dashboard/content',
            builder: (_, state) => const ContentPage(),
          ),
          GoRoute(
            path: '/dashboard/settings',
            builder: (_, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Empty(
          'Halaman tidak ditemukan',
          action: ElevatedButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Ke beranda'),
          ),
        ),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class SessionLoadingPage extends ConsumerWidget {
  const SessionLoadingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: auth.error == null
                  ? const Loading()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Brand(),
                        const SizedBox(height: 24),
                        ErrorNotice(
                          auth.error!,
                          retry: () =>
                              ref.read(authProvider.notifier).restore(),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              ref.read(authProvider.notifier).forget(),
                          child: const Text('Ke halaman masuk'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
