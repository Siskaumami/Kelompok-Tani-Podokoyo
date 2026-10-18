import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/feature_provider.dart';
import '../../../core/network/external_links.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/forms/form_spec.dart';
import '../../../core/widgets/forms/mutation_dialog.dart';
import '../../../core/widgets/private_image.dart';

class ContentPage extends ConsumerWidget {
  const ContentPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(objectProvider('/organization'))
      .when(
        loading: () => const Loading(),
        error: (error, stack) => ErrorNotice(
          error,
          retry: () => ref.invalidate(objectProvider('/organization')),
        ),
        data: (org) {
          void edit() => showMutationForm(
            context,
            ref,
            FormSpec(
              title: 'Edit profil desa',
              path: '/organization/content',
              method: 'PUT',
              initial: org.json,
              fields: const [
                FieldSpec('village_title', 'Judul profil', optional: true),
                FieldSpec(
                  'publication',
                  'Tampil di website',
                  kind: InputKind.select,
                  choices: publicationChoices,
                ),
                FieldSpec(
                  'village_body',
                  'Cerita desa dan kelompok tani',
                  kind: InputKind.textarea,
                  optional: true,
                  maxLength: 15000,
                ),
                FieldSpec(
                  'village_image_id',
                  'Gambar utama',
                  kind: InputKind.image,
                  optional: true,
                ),
              ],
              prepare: (v) {
                if (v['publication'] == 'PUBLISHED' &&
                    ((v['village_title'] as String).isEmpty ||
                        (v['village_body'] as String).isEmpty)) {
                  throw const FormatException(
                    'Isi judul dan profil sebelum diterbitkan.',
                  );
                }
                return v;
              },
            ),
          );
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeading(
                  'Konten website',
                  action: ElevatedButton(
                    onPressed: edit,
                    child: const Text('Edit profil desa'),
                  ),
                ),
                Panel(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width <= 640 ? 24 : 30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'PROFIL DESA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                                color: Color(0xff416b4e),
                              ),
                            ),
                          ),
                          StatusBadge(org.s('publication')),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (org.s('village_title').isEmpty &&
                          org.s('village_body').isEmpty)
                        Empty(
                          'Profil desa belum ditulis',
                          description: 'Ceritakan desa, kelompok tani, dan kegiatan yang benar-benar dijalankan.',
                          action: ElevatedButton(
                            onPressed: edit,
                            child: const Text('Tulis profil desa'),
                          ),
                        )
                      else ...[
                        Text(
                          org.s('village_title').isEmpty
                              ? 'Judul belum diisi'
                              : org.s('village_title'),
                          style: TextStyle(
                            fontSize:
                                MediaQuery.sizeOf(context).width <= 640 ? 25 : 28,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.1,
                            height: 1.15,
                          ),
                        ),
                        if (org.s('village_image_id').isNotEmpty) ...[
                          const SizedBox(height: 15),
                          PrivateImage(
                            org.s('village_image_id'),
                            height: 240,
                            fit: BoxFit.cover,
                            radius: 10,
                          ),
                          const SizedBox(height: 25),
                        ] else
                          const SizedBox(height: 12),
                        Text(
                          org.s('village_body').isEmpty
                              ? 'Profil belum diisi.'
                              : org.s('village_body'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xff63816c),
                            height: 1.9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, c) {
                    final width = c.maxWidth > 700
                        ? (c.maxWidth - 24) / 3
                        : c.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: width,
                          child: QuickLinkCard(
                            icon: Icons.people_outline,
                            title: 'Profil anggota',
                            body:
                                'Kelola informasi petani yang tampil di website.',
                            onTap: () => context.go('/dashboard/farmers'),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: QuickLinkCard(
                            icon: Icons.inventory_2_outlined,
                            title: 'Katalog produk',
                            body: 'Kelola produk dan tautan pembelian.',
                            onTap: () => context.go('/dashboard/products'),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: QuickLinkCard(
                            icon: Icons.eco_outlined,
                            title: 'Lihat website',
                            body: 'Periksa informasi yang sudah terbit.',
                            onTap: () async {
                              try {
                                await ref
                                    .read(externalLinksProvider)
                                    .website();
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: ErrorNotice(error)),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
}
