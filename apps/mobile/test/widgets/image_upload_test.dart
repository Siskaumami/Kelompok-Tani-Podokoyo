import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tani_mobile/app/providers.dart';
import 'package:tani_mobile/core/auth/auth_controller.dart';
import 'package:tani_mobile/core/network/file_service.dart';
import 'package:tani_mobile/core/theme/tokens.dart';
import 'package:tani_mobile/core/widgets/forms/form_spec.dart';
import 'package:tani_mobile/core/widgets/forms/mutation_dialog.dart';

import '../support/fakes.dart';
import '../support/widget_app.dart';

class GalleryFixture extends FileService {
  GalleryFixture(super.api, this.bytes);
  final Uint8List bytes;
  @override
  Future<UploadDraft?> select() async => UploadDraft(bytes, 'fixture.png');
}

void main() {
  setUpAll(initializeWidgetTests);
  testWidgets(
    'uncertain gallery upload locks submit, manually reuses upload key, then attaches returned file id',
    (tester) async {
      final h = TestHarness();
      await tester.runAsync(
        () => h.container.read(authProvider.notifier).restore(),
      );
      final data = await rootBundle.load('assets/branding/icon-192.png');
      final bytes = data.buffer.asUint8List();
      var calls = 0;
      h.server.overrides['POST /files'] = (r) {
        if (calls++ == 0) {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return const Reply({'id': recordId});
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiProvider.overrideWithValue(h.api),
            fileServiceProvider.overrideWithValue(GalleryFixture(h.api, bytes)),
            imageProvider(recordId).overrideWith((ref) async => bytes),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<FormOutcome>(
                    context: context,
                    builder: (_) => const MutationDialog(
                      spec: FormSpec(
                        title: 'Foto petani',
                        path: '/farmers',
                        initial: {'name': 'Petani uji'},
                        fields: [
                          FieldSpec('name', 'Nama petani'),
                          FieldSpec(
                            'image_id',
                            'Foto profil',
                            kind: InputKind.image,
                            optional: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih gambar'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Simpan'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Coba lagi'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      final uploads = h.server.adapter.requests
          .where((r) => r.uri.path.endsWith('/files'))
          .toList();
      expect(
        uploads[0].headers['Idempotency-Key'],
        uploads[1].headers['Idempotency-Key'],
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(bodyOf(h.server.adapter.requests.last)['image_id'], recordId);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      h.dispose();
    },
  );
}
