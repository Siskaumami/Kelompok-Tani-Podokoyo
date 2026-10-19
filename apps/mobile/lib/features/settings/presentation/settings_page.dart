import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../app/providers.dart';
import '../../../core/data/feature_provider.dart';
import '../../../core/network/external_links.dart';
import '../../../core/network/mutation.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/forms/form_spec.dart';
import '../../../core/widgets/forms/mutation_dialog.dart';
import '../../products/data/product_feature.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return ref
        .watch(objectProvider('/organization'))
        .when(
          loading: () => const Loading(),
          error: (error, stack) => ErrorNotice(
            error,
            retry: () => ref.invalidate(objectProvider('/organization')),
          ),
          data: (org) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeading('Pengaturan'),
                LayoutBuilder(
                  builder: (context, c) {
                    final width = c.maxWidth > 800
                        ? (c.maxWidth - 20) / 2
                        : c.maxWidth;
                    return Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        SizedBox(
                          width: width,
                          child: Panel(
                            padding: EdgeInsets.all(
                              MediaQuery.sizeOf(context).width <= 640 ? 24 : 28,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Organisasi & operasional',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.6,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SettingRow('Nama', org.s('name')),
                                SettingRow(
                                  'Pengingat penjualan',
                                  org.flag('reminders_enabled')
                                      ? org.s('reminder_time').substring(0, 5)
                                      : 'Dinonaktifkan',
                                ),
                                if (user?.isOwner ?? false)
                                  OutlinedButton(
                                    onPressed: () => showMutationForm(
                                      context,
                                      ref,
                                      FormSpec(
                                        title: 'Pengaturan organisasi',
                                        path: '/organization/settings',
                                        method: 'PUT',
                                        initial: {
                                          ...org.json,
                                          'reminder_time': org
                                              .s('reminder_time')
                                              .substring(0, 5),
                                        },
                                        fields: const [
                                          FieldSpec(
                                            'name',
                                            'Nama kelompok tani',
                                          ),
                                          FieldSpec(
                                            'reminder_time',
                                            'Jam pengingat',
                                            kind: InputKind.time,
                                            hint: 'Format 24 jam, HH:mm',
                                          ),
                                          FieldSpec(
                                            'reminders_enabled',
                                            'Aktifkan pengingat harian',
                                            kind: InputKind.toggle,
                                          ),
                                          FieldSpec(
                                            'reminder_email',
                                            'Kirim pengingat lewat email',
                                            kind: InputKind.toggle,
                                          ),
                                        ],
                                        prepare: (v) =>
                                            settingsPayload(org, overrides: v),
                                      ),
                                    ),
                                    child: const Text('Ubah pengaturan'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: Panel(
                            padding: EdgeInsets.all(
                              MediaQuery.sizeOf(context).width <= 640 ? 24 : 28,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Keamanan akun',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.6,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(user?.name ?? ''),
                                Text(
                                  user?.email ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Kata sandi baru mencabut semua sesi akun ini. Anda akan diminta masuk kembali.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xff748c7c),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () => showMutationForm(
                                    context,
                                    ref,
                                    FormSpec(
                                      title: 'Ganti kata sandi',
                                      path: '/auth/change-password',
                                      authAction: true,
                                      afterSave: AfterSave.passwordChanged,
                                      fields: const [
                                        FieldSpec(
                                          'current_password',
                                          'Kata sandi saat ini',
                                          kind: InputKind.password,
                                          maxLength: 128,
                                        ),
                                        FieldSpec(
                                          'password',
                                          'Kata sandi baru',
                                          kind: InputKind.password,
                                          maxLength: 128,
                                          hint: 'Minimal 12 karakter.',
                                        ),
                                      ],
                                      prepare: (v) {
                                        if ((v['password'] as String).length <
                                            12) {
                                          throw const FormatException(
                                            'Kata sandi minimal 12 karakter.',
                                          );
                                        }
                                        return v;
                                      },
                                    ),
                                  ),
                                  child: const Text('Ganti kata sandi'),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () =>
                                      ref.read(externalLinksProvider).privacy(),
                                  child: const Text('Kebijakan Privasi'),
                                ),
                                const SizedBox(height: 12),
                                if (user?.isOwner ?? false)
                                  const Notice(
                                    'Untuk menghapus akun Pengelola Utama, pindahkan peran Pengelola Utama ke Admin lain terlebih dahulu.',
                                  )
                                else
                                  OutlinedButton(
                                    onPressed: () => showMutationForm(
                                      context,
                                      ref,
                                      const FormSpec(
                                        title: 'Hapus akun',
                                        path: '/auth/delete-account',
                                        authAction: true,
                                        afterSave: AfterSave.accountDeleted,
                                        submitLabel: 'Hapus akun',
                                        description: 'Akses akun akan dihapus dan data pribadi akun akan dianonimkan. Catatan transaksi dan riwayat aktivitas organisasi tetap disimpan.',
                                        fields: [
                                          FieldSpec(
                                            'current_password',
                                            'Kata sandi saat ini',
                                            kind: InputKind.password,
                                            maxLength: 128,
                                          ),
                                        ],
                                      ),
                                    ),
                                    child: const Text('Hapus akun'),
                                  ),
                                const Divider(),
                                const Text(
                                  'Pengingat di perangkat',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Konfirmasi pencatatan penjualan untuk menghentikan pengingat pada hari tersebut.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xff748c7c),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const DeviceNotificationControl(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
  }
}

class DeviceNotificationControl extends ConsumerStatefulWidget {
  const DeviceNotificationControl({super.key});

  @override
  ConsumerState<DeviceNotificationControl> createState() =>
      _DeviceNotificationControlState();
}

class _DeviceNotificationControlState
    extends ConsumerState<DeviceNotificationControl> {
  bool _busy = false;
  bool _enabled = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      final state = await ref.read(apiProvider).get('/notifications');

      final permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      final registered =
          state is Map && state['mobile_push_registered'] == true;

      if (!mounted) return;

      setState(() {
        _enabled = permissionGranted && registered;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _enabled = false;
      });
    }
  }

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        if (!mounted) return;

        setState(() {
          _enabled = false;
          _message = 'Izin notifikasi belum diberikan. Aktifkan izin notifikasi untuk menerima pengingat.';
        });
        return;
      }

      final messaging = FirebaseMessaging.instance;
      final registration = messaging.onRegistered.first;

      await messaging.register();

      final installationId = await registration;

      if (installationId.isEmpty) {
        throw StateError('Identitas notifikasi belum tersedia.');
      }

      await ref
          .read(apiProvider)
          .mutate(
            PendingMutation(
              path: '/notifications/mobile',
              method: 'POST',
              payload: {
                'fid': installationId,
                'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
              },
            ),
          );

      if (!mounted) return;

      setState(() {
        _enabled = true;
        _message = 'Notifikasi perangkat aktif.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _enabled = false;
        _message = 'Notifikasi perangkat belum dapat diaktifkan. Coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton(
          onPressed: _busy || _enabled ? null : _activate,
          child: Text(
            _busy
                ? 'Mengaktifkan…'
                : _enabled
                ? 'Notifikasi aktif'
                : 'Aktifkan notifikasi',
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Notice(_message!),
        ],
      ],
    );
  }
}
