import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/data/feature_provider.dart';
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
                                const Notice(
                                  'Notifikasi perangkat belum tersedia. Pengingat di aplikasi tetap dapat digunakan.',
                                ),
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
