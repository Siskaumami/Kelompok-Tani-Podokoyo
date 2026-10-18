import '../auth/auth_controller.dart';

import 'package:dio/dio.dart';

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../errors/app_error.dart';
import 'api_client.dart';
import 'json_data.dart';
import 'mutation.dart';

class UploadDraft {
  UploadDraft(Uint8List value, this.filename)
    : bytes = value.asUnmodifiableView(),
      key = uuidV4();
  final Uint8List bytes;
  final String filename;
  final String key;
}

class FileService {
  const FileService(this.api);
  final ApiClient api;
  Future<UploadDraft?> select() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    if (await image.length() > 5 * 1024 * 1024) {
      throw const AppError(
        'Ukuran gambar maksimal 5 MB.',
        code: 'FILE_TOO_LARGE',
      );
    }
    final bytes = await image.readAsBytes();
    validateImage(bytes);
    return UploadDraft(bytes, image.name);
  }

  Future<String> upload(UploadDraft draft) async {
    final result = RecordData(
      await api.upload(draft.bytes, draft.filename, draft.key),
    );
    return result.validate(strings: ['id']).id;
  }
}

final fileServiceProvider = Provider<FileService>(
  (ref) => FileService(ref.watch(apiProvider)),
);
final imageProvider = FutureProvider.autoDispose.family<Uint8List, String>((
  ref,
  id,
) {
  ref.watch(dataEpochProvider);
  requireAuthenticated(ref);
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return ref.watch(apiProvider).image(id, cancelToken: token);
});
