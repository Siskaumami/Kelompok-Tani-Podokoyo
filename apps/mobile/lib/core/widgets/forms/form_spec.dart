import '../../network/json_data.dart';
import '../../utils/format.dart';

enum InputKind {
  text,
  textarea,
  integer,
  kg,
  date,
  select,
  toggle,
  image,
  password,
  email,
  time,
}

class Choice {
  const Choice(this.value, this.label);
  final String value;
  final String label;
}

const publicationChoices = [
  Choice('DRAFT', 'Belum ditampilkan'),
  Choice('PUBLISHED', 'Tampilkan di website'),
];
final reasonChoices = reasonNames.entries
    .map((entry) => Choice(entry.key, entry.value))
    .toList(growable: false);

class FieldSpec {
  const FieldSpec(
    this.name,
    this.label, {
    this.kind = InputKind.text,
    this.optional = false,
    this.positive = false,
    this.unit,
    this.hint,
    this.maxLength = 200,
    this.choices = const [],
    this.enabled,
  });
  final String name;
  final String label;
  final InputKind kind;
  final bool optional;
  final bool positive;
  final String? unit;
  final String? hint;
  final int maxLength;
  final List<Choice> choices;
  final bool Function(Map<String, Object?> values)? enabled;
}

enum AfterSave { refresh, verifySession, passwordChanged, accountDeleted }

class FormSpec {
  const FormSpec({
    required this.title,
    required this.path,
    this.method = 'POST',
    this.description,
    this.fields = const [],
    this.initial = const {},
    this.prepare,
    this.summary,
    this.normalize,
    this.submitLabel = 'Simpan',
    this.afterSave = AfterSave.refresh,
    this.authAction = false,
  });
  final String title;
  final String path;
  final String method;
  final String? description;
  final List<FieldSpec> fields;
  final Json initial;
  final Json Function(Json payload)? prepare;
  final String? Function(Json values)? summary;
  final void Function(Json values)? normalize;
  final String submitLabel;
  final AfterSave afterSave;
  final bool authAction;

  Json initialValues() => {
    for (final field in fields)
      field.name: field.kind == InputKind.toggle
          ? valueAt(initial, field.name) == true
          : field.kind == InputKind.kg && valueAt(initial, field.name) != null
          ? kgInput(valueAt(initial, field.name)!)
          : valueAt(initial, field.name) ?? '',
  };

  Json payload(Json values) {
    final result = <String, Object?>{};
    for (final field in fields) {
      final enabled = field.enabled?.call(values) ?? true;
      Object? value = values[field.name];
      if (!enabled) {
        value = null;
      } else if (field.kind == InputKind.toggle) {
        value = value == true;
      } else {
        var text = (value ?? '').toString();
        if (field.kind != InputKind.password) text = text.trim();
        if (text.isEmpty && !field.optional) {
          throw FormatException('${field.label} wajib diisi.');
        }
        if (text.length > field.maxLength) {
          throw FormatException(
            '${field.label} maksimal ${field.maxLength} karakter.',
          );
        }
        value = switch (field.kind) {
          InputKind.kg => integerInput(
            grams(text.isEmpty && field.optional ? '0' : text),
            positive: field.positive,
          ),
          InputKind.integer => integerInput(
            text.isEmpty && field.optional ? '0' : text,
            positive: field.positive,
          ),
          InputKind.date => validDate(text),
          InputKind.image => text.isEmpty ? null : text,
          _ => text,
        };
        if (field.kind == InputKind.select &&
            text.isNotEmpty &&
            !field.choices.any((c) => c.value == text)) {
          throw FormatException(
            'Pilih ${field.label.toLowerCase()} yang tersedia.',
          );
        }
        if (field.kind == InputKind.email &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
          throw const FormatException('Email tidak valid.');
        }
        if (field.kind == InputKind.time &&
            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(text)) {
          throw const FormatException('Jam menggunakan format 24 jam, HH:mm.');
        }
      }
      setAt(result, field.name, value);
    }
    return prepare?.call(result) ?? result;
  }
}

Object? valueAt(Json value, String path) {
  Object? current = value;
  for (final part in path.split('.')) {
    current = current is Map ? current[part] : null;
  }
  return current;
}

void setAt(Json target, String path, Object? value) {
  final parts = path.split('.');
  var current = target;
  for (final part in parts.take(parts.length - 1)) {
    current[part] ??= <String, Object?>{};
    current = current[part] as Json;
  }
  current[parts.last] = value;
}

FormSpec reasonForm(String path, String title, String description) => FormSpec(
  title: title,
  path: path,
  description: description,
  fields: const [
    FieldSpec(
      'reason',
      'Alasan',
      kind: InputKind.textarea,
      maxLength: 1000,
      hint: 'Jelaskan koreksi agar riwayat mudah dipahami.',
    ),
  ],
  prepare: (v) {
    if ((v['reason'] as String).length < 3) {
      throw const FormatException('Alasan minimal 3 karakter.');
    }
    return v;
  },
);
FormSpec simpleForm(
  String path,
  String title,
  String description, {
  Json initial = const {},
}) => FormSpec(
  title: title,
  path: path,
  description: description,
  submitLabel: title,
  prepare: (_) => initial,
);
