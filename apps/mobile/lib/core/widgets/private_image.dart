import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/file_service.dart';
import 'common.dart';

class PrivateImage extends ConsumerWidget {
  const PrivateImage(
    this.id, {
    super.key,
    this.height = 160,
    this.fit = BoxFit.contain,
    this.radius = 8,
  });
  final String id;
  final double height;
  final BoxFit fit;
  final double radius;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(imageProvider(id))
      .when(
        data: (bytes) => ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.memory(
            bytes,
            height: height,
            width: double.infinity,
            fit: fit,
            semanticLabel: 'Gambar yang dipilih',
            errorBuilder: (_, error, stack) =>
                const Notice('Gambar belum dapat ditampilkan.', error: true),
          ),
        ),
                error: (error, stack) =>
            ErrorNotice(error, retry: () => ref.invalidate(imageProvider(id))),
        loading: () => SizedBox(
          height: height,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
}