import 'package:flutter/material.dart';

import '../../network/json_data.dart';
import '../../utils/format.dart';
import 'form_spec.dart';
import 'image_field.dart';

class SpecInput extends StatefulWidget {
  const SpecInput({
    super.key,
    required this.field,
    required this.values,
    required this.locked,
    required this.onChanged,
    required this.onUploadBusy,
  });
  final FieldSpec field;
  final Json values;
  final bool locked;
  final ValueChanged<Object?> onChanged;
  final ValueChanged<bool> onUploadBusy;
  @override
  State<SpecInput> createState() => _SpecInputState();
}

class _SpecInputState extends State<SpecInput> {
  late final TextEditingController _controller;
  bool _obscure = true;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.values[widget.field.name] ?? '').toString(),
    );
  }

  @override
  void didUpdateWidget(SpecInput old) {
    super.didUpdateWidget(old);
    final value = (widget.values[widget.field.name] ?? '').toString();
    if (value != _controller.text) _controller.text = value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _date() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_controller.text) ?? DateTime.now(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (date != null && mounted) widget.onChanged(isoDate(date));
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final enabled =
        !widget.locked && (field.enabled?.call(widget.values) ?? true);
    final value = widget.values[field.name];
    Widget input;
    if (field.kind == InputKind.toggle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          controlAffinity: ListTileControlAffinity.trailing,
          title: Text(
            field.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xff45684e),
            ),
          ),
          value: value == true,
          onChanged: enabled ? widget.onChanged : null,
        ),
      );
    }
    if (field.kind == InputKind.image) {
      input = ImageField(
        value: (value ?? '').toString(),
        enabled: enabled,
        onChanged: widget.onChanged,
        onBusy: widget.onUploadBusy,
      );
    } else if (field.kind == InputKind.select) {
      final selected =
          enabled &&
              value is String &&
              field.choices.any((c) => c.value == value)
          ? value
          : null;
      input = DropdownButtonFormField<String>(
        style: const TextStyle(fontSize: 14, color: Color(0xff213f2a)),
        key: ValueKey('${field.name}:$selected:$enabled'),
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(),
        hint: const Text('Pilih…'),
        items: field.choices
            .map(
              (c) => DropdownMenuItem(
                value: c.value,
                child: Text(c.label, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: enabled ? widget.onChanged : null,
        validator: (value) =>
            enabled && !field.optional && (value == null || value.isEmpty)
            ? '${field.label} wajib diisi.'
            : null,
      );
    } else {
      final password = field.kind == InputKind.password;
      input = TextFormField(
        key: ValueKey('field.${field.name}'),
        controller: _controller,
        enabled: enabled,
        obscureText: password && _obscure,
        enableSuggestions: !password,
        autocorrect: !password,
        readOnly: field.kind == InputKind.date,
        onTap: field.kind == InputKind.date ? _date : null,
        keyboardType: switch (field.kind) {
          InputKind.email => TextInputType.emailAddress,
          InputKind.integer => TextInputType.number,
          InputKind.kg => const TextInputType.numberWithOptions(decimal: true),
          InputKind.time => TextInputType.datetime,
          InputKind.textarea => TextInputType.multiline,
          _ => TextInputType.text,
        },
        maxLines: field.kind == InputKind.textarea ? 5 : 1,
        maxLength: field.maxLength,
        autofillHints: field.kind == InputKind.email
            ? const [AutofillHints.email]
            : null,
        style: const TextStyle(fontSize: 14),
        textInputAction: field.kind == InputKind.textarea
            ? TextInputAction.newline
            : TextInputAction.next,
        decoration: InputDecoration(
          counterText: '',
          suffixText: field.unit,
          suffixIcon: password
              ? IconButton(
                  tooltip: _obscure
                      ? 'Tampilkan kata sandi'
                      : 'Sembunyikan kata sandi',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                )
              : field.kind == InputKind.date
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : null,
        ),
        validator: (raw) {
          if (!enabled) return null;
          final text = raw ?? '';
          if ((field.kind == InputKind.password
                  ? text.isEmpty
                  : text.trim().isEmpty) &&
              !field.optional) {
            return '${field.label} wajib diisi.';
          }
          return null;
        },
        onChanged: widget.onChanged,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${field.label}${field.optional ? '' : ' *'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          input,
          if (field.hint != null || field.kind == InputKind.kg)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                field.hint ??
                    'Gunakan koma untuk desimal; tanpa titik pemisah ribuan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
