import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../auth/auth_controller.dart';
import '../../errors/app_error.dart';
import '../../network/json_data.dart';
import '../../network/mutation.dart';
import '../common.dart';
import 'form_spec.dart';
import 'spec_input.dart';

enum FormOutcome { saved, closed, refreshBaseline }

Future<bool> showMutationForm(
  BuildContext context,
  WidgetRef ref,
  FormSpec spec, {
  Widget Function(bool locked, VoidCallback changed)? extra,
}) async {
  final outcome = await showDialog<FormOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => MutationDialog(spec: spec, extra: extra),
  );
  if (outcome == FormOutcome.refreshBaseline && context.mounted) {
    final path = spec.path.replaceFirst(RegExp(r'/complete$'), '/refresh');
    return showMutationForm(
      context,
      ref,
      simpleForm(
        path,
        'Gunakan stok terbaru',
        'Stok tercatat akan diperbarui. Setelah itu, hitung kembali jumlah barang yang ada.',
      ),
    );
  }
  if (!context.mounted) return outcome == FormOutcome.saved;
  final auth = ref.read(authProvider.notifier);
  if (outcome == FormOutcome.saved &&
      (spec.afterSave == AfterSave.passwordChanged ||
          spec.afterSave == AfterSave.accountDeleted)) {
    await auth.forget();
    return true;
  }
  if (outcome == FormOutcome.saved &&
      spec.afterSave == AfterSave.verifySession) {
    await auth.verify(blocking: true);
    return true;
  }
  ref.read(dataEpochProvider.notifier).advance();
  if (outcome != FormOutcome.saved) return false;
  if (context.mounted) {
    showSuccess(
      context,
      spec.path == '/sales'
          ? 'Penjualan berhasil dicatat.'
          : 'Perubahan berhasil disimpan.',
    );
  }
  return true;
}

class MutationDialog extends ConsumerStatefulWidget {
  const MutationDialog({super.key, required this.spec, this.extra});
  final FormSpec spec;
  final Widget Function(bool locked, VoidCallback changed)? extra;
  @override
  ConsumerState<MutationDialog> createState() => _MutationDialogState();
}

class _MutationDialogState extends ConsumerState<MutationDialog> {
  final _form = GlobalKey<FormState>();
  late final Json _values;
  bool _busy = false;
  bool _uploadBusy = false;
  bool _uncertain = false;
  AppError? _error;
  PendingMutation? _pending;
  bool get locked => _busy || _uncertain || _uploadBusy;
  @override
  void initState() {
    super.initState();
    _values = widget.spec.initialValues();
  }

  void _change(String key, Object? value) {
    if (locked) return;
    setState(() {
      _values[key] = value;
      widget.spec.normalize?.call(_values);
      _pending = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || _uploadBusy) return;
    if (!_uncertain && !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _pending ??= PendingMutation(
        path: widget.spec.path,
        method: widget.spec.method,
        payload: widget.spec.payload(_values),
      );
      if (widget.spec.authAction) {
        await ref
            .read(apiProvider)
            .authPost(widget.spec.path, _pending!.payload, authenticated: true);
      } else {
        await ref.read(repositoryProvider).save(_pending!);
      }
      if (mounted) {
        setState(() => _busy = false);
        Navigator.of(context).pop(FormOutcome.saved);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AppError.from(error);
          _uncertain = _error!.uncertain;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final summary = spec.summary?.call(_values);
    final phone = MediaQuery.sizeOf(context).width <= 640;
    return PopScope(
      canPop: !_busy && !_uploadBusy,
      child: Dialog(
        insetPadding: EdgeInsets.all(phone ? 10 : 12),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xffd2e1d6)),
          borderRadius: BorderRadius.circular(phone ? 13 : 16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 760,
            maxHeight: MediaQuery.sizeOf(context).height - (phone ? 20 : 40),
          ),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    phone ? 18 : 20,
                    14,
                    phone ? 8 : 10,
                    10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          spec.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        iconSize: 20,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.all(10),
                        ),
                        onPressed: _busy || _uploadBusy
                            ? null
                            : () =>
                                  Navigator.of(context).pop(FormOutcome.closed),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      phone ? 19 : 20,
                      phone ? 22 : 20,
                      phone ? 19 : 20,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (spec.description != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(spec.description!),
                          ),
                        for (final field in spec.fields)
                          SpecInput(
                            key: ValueKey(field.name),
                            field: field,
                            values: _values,
                            locked: field.kind == InputKind.image
                                ? (_busy || _uncertain)
                                : locked,
                            onChanged: (value) => _change(field.name, value),
                            onUploadBusy: (value) =>
                                setState(() => _uploadBusy = value),
                          ),
                        if (widget.extra != null)
                          widget.extra!(locked, () {
                            if (!locked) setState(() => _pending = null);
                          }),
                        if (summary != null)
                          Panel(
                            child: Text(
                              summary,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          ErrorNotice(_error!),
                          if (_error!.staleBaseline)
                            OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(context)
                                      .pop(FormOutcome.refreshBaseline),
                              child: const Text('Gunakan stok terbaru'),
                            ),
                        ],
                        if (_uncertain)
                          const Notice(
                            'Koneksi terputus saat menyimpan. Data mungkin sudah tersimpan. Coba lagi untuk memastikan. Jika menutup formulir ini, periksa riwayat sebelum membuat catatan baru.',
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    phone ? 19 : 16,
                    phone ? 18 : 16,
                    phone ? 19 : 16,
                    phone ? 18 : 16,
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _busy || _uploadBusy
                            ? null
                            : () =>
                                  Navigator.of(context).pop(FormOutcome.closed),
                        child: Text(
                          _uncertain ? 'Tutup dan periksa catatan' : 'Batal',
                        ),
                      ),
                      if (_uncertain && spec.authAction)
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop(FormOutcome.closed);
                            await ref.read(authProvider.notifier).forget();
                          },
                          child: const Text('Ke halaman masuk'),
                        )
                      else
                        ElevatedButton(
                          onPressed: _busy || _uploadBusy ? null : _submit,
                          child: Text(
                            _busy
                                ? 'Menyimpan…'
                                : _uncertain
                                ? 'Coba lagi'
                                : spec.submitLabel,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
