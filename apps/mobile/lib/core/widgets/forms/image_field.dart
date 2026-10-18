import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../errors/app_error.dart';
import '../../network/file_service.dart';
import '../common.dart';
import '../private_image.dart';

class ImageField extends ConsumerStatefulWidget {
  const ImageField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.enabled,
    required this.onBusy,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onBusy;
  final bool enabled;
  @override
  ConsumerState<ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends ConsumerState<ImageField> {
  bool _busy = false;
  UploadDraft? _pending;
  AppError? _error;
  bool _uncertain = false;
  Future<void> _upload({bool retry = false}) async {
    setState(() => _busy = true);
    widget.onBusy(true);
    try {
      final service = ref.read(fileServiceProvider);
      if (!retry) _pending = await service.select();
      if (_pending == null) return;
      final id = await service.upload(_pending!);
      if (!mounted) return;
      widget.onBusy(false);
      widget.onChanged(id);
      _pending = null;
      _uncertain = false;
      _error = null;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AppError.from(error, write: _pending != null);
          _uncertain = _error!.uncertain;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusy(_uncertain);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (widget.value.isNotEmpty)
            SizedBox(
              width: 75,
              child: PrivateImage(
                widget.value,
                height: 75,
                fit: BoxFit.cover,
              ),
            ),
          OutlinedButton.icon(
            onPressed: widget.enabled && !_busy && !_uncertain
                ? () => _upload()
                : null,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Pilih gambar'),
          ),
          if (widget.value.isNotEmpty)
            TextButton(
              onPressed: widget.enabled && !_busy && !_uncertain
                  ? () => widget.onChanged('')
                  : null,
              child: const Text('Lepas gambar'),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'JPEG, PNG atau WebP · maksimal 5 MB',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (_busy) const Loading(),
      if (_error != null) ErrorNotice(_error!),
      if (_uncertain) ...[
        const Notice(
          'Koneksi terputus saat mengunggah. Coba lagi untuk memastikan gambar tersimpan.',
        ),
        OutlinedButton(
          onPressed: widget.enabled && !_busy
              ? () => _upload(retry: true)
              : null,
          child: const Text('Coba lagi'),
        ),
      ],
    ],
  );
}
