import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/errors/app_error.dart';
import '../core/network/external_links.dart';
import '../core/theme/tokens.dart';
import '../core/widgets/common.dart';
import 'navigation.dart';

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.child,
    required this.location,
  });
  final Widget child;
  final String location;
  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  bool _loggingOut = false;
  AppError? _error;
  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await ref.read(authProvider.notifier).logout();
    } catch (error) {
      if (mounted) setState(() => _error = AppError.from(error));
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Widget _navItem(int index, bool drawer) {
    final destination = destinations[index];
    final selected = widget.location == destination.path;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (drawer) Navigator.of(context).pop();
            context.go(destination.path);
          },
          child: Container(
            height: 41,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? Tokens.selected : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  size: 18,
                  color: selected
                      ? const Color(0xff176f35)
                      : const Color(0xff57725f),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? const Color(0xff176f35)
                          : const Color(0xff57725f),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebar(bool drawer) => SafeArea(
    child: Container(
      width: 248,
      color: Tokens.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 68,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Align(alignment: Alignment.centerLeft, child: Brand()),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                for (var i = 0; i < destinations.length; i++) ...[
                  if ([1, 3, 6, 9, 10].contains(i)) const Divider(height: 18),
                  _navItem(i, drawer),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ErrorNotice(_error!),
                LayoutBuilder(
                  builder: (context, _) {
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(1) >= 1.4;

                    final websiteButton = TextButton.icon(
                      onPressed: () async {
                        try {
                          await ref.read(externalLinksProvider).website();
                        } catch (error) {
                          if (mounted) {
                            setState(() => _error = AppError.from(error));
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text(
                        'Lihat website',
                        style: TextStyle(fontSize: 10),
                      ),
                    );

                    final logoutButton = TextButton.icon(
                      onPressed: _loggingOut ? null : _logout,
                      icon: const Icon(Icons.logout, size: 16),
                      label: Text(
                        _loggingOut ? 'Memproses…' : 'Keluar',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );

                    if (largeText) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          websiteButton,
                          logoutButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: websiteButton),
                        Expanded(child: logoutButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.roleLabel ?? '';
    final current =
        destinations
            .where((d) => d.path == widget.location)
            .firstOrNull
            ?.label ??
        'Operasional';
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= Tokens.sidebarBreakpoint;
        return Scaffold(
          key: _scaffold,
          drawer: wide ? null : Drawer(width: 248, child: _sidebar(true)),
          body: SafeArea(
            child: Row(
              children: [
                if (wide) _sidebar(false),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        constraints: const BoxConstraints(minHeight: 73),
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 25 : 8,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: Color(0xffe1ece4)),
                          ),
                        ),
                        child: Builder(
                          builder: (context) {
                            final largeText =
                                MediaQuery.textScalerOf(context).scale(1) >= 1.4;

                            if (!wide && largeText) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Buka navigasi',
                                        onPressed: () =>
                                            _scaffold.currentState?.openDrawer(),
                                        icon: const Icon(Icons.menu),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Ruang kerja / $current',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      48,
                                      0,
                                      8,
                                      8,
                                    ),
                                    child: Text(
                                      role,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Tokens.muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                if (!wide)
                                  IconButton(
                                    tooltip: 'Buka navigasi',
                                    onPressed: () =>
                                        _scaffold.currentState?.openDrawer(),
                                    icon: const Icon(Icons.menu),
                                  ),
                                Expanded(
                                  child: Text(
                                    'Ruang kerja / $current',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xffdce8de),
                                    ),
                                    borderRadius: BorderRadius.circular(9),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.eco_outlined,
                                        size: 18,
                                        color: Tokens.accent,
                                      ),
                                      const SizedBox(width: 6),
                                      SizedBox(
                                        width: wide ? 112 : 78,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Ruang kerja',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              role,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color: Tokens.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 25 : 16,
                            25,
                            wide ? 25 : 16,
                            0,
                          ),
                          child: widget.child,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
