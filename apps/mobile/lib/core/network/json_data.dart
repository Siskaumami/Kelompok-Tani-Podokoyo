import 'dart:collection';

import '../errors/app_error.dart';

typedef Json = Map<String, Object?>;
Json jsonObject(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw AppError.malformed();
  }
  return Map<String, Object?>.from(value);
}

class RecordData {
  RecordData(Object? value)
    : _data = UnmodifiableMapView(_freezeJson(jsonObject(value)) as Json) {
    for (final key in _data.keys) {
      final value = _data[key];
      if (value == null) continue;
      if (key == 'id' || key.endsWith('_id')) {
        if (value is! String ||
            !RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(value)) {
          throw AppError.malformed();
        }
      }
      if (key.endsWith('_rp') ||
          key.endsWith('_g') ||
          _integerFields.contains(key)) {
        number(key);
      }
      if (_booleanFields.contains(key)) flag(key);
      if (_stringFields.contains(key)) s(key);
    }
  }
  final Map<String, Object?> _data;
  Json get json => _copyJson(_data) as Json;
  String s(String key, [String fallback = '']) {
    final value = _data[key];
    if (value == null) return fallback;
    if (value is! String) throw AppError.malformed();
    return value;
  }

  String number(String key, [String? fallback]) {
    final value = _data[key] ?? fallback;
    if (value is! String && value is! int) throw AppError.malformed();
    final result = '$value';
    if (!RegExp(r'^-?(0|[1-9]\d*)$').hasMatch(result)) {
      throw AppError.malformed();
    }
    return result;
  }

  bool flag(String key, [bool fallback = false]) {
    final value = _data[key];
    if (value == null) return fallback;
    if (value is! bool) throw AppError.malformed();
    return value;
  }

  Object? operator [](String key) => _data[key];
  String get id => s('id');
  String get status => s('status');
  String get kind => s('kind');
  bool get archived => flag('archived');
  RecordData object(String key) => RecordData(_data[key]);
  List<RecordData> rows(String key) => records(_data[key]);

  RecordData validate({
    List<String> strings = const [],
    List<String> integers = const [],
  }) {
    for (final key in strings) {
      if (s(key).isEmpty) throw AppError.malformed();
    }
    for (final key in integers) {
      number(key);
    }
    return this;
  }
}

List<RecordData> records(Object? value) {
  if (value is! List || value.length > 10000) throw AppError.malformed();
  return List.unmodifiable(value.map(RecordData.new));
}

class RecordPage {
  const RecordPage(this.items, this.nextOffset);
  factory RecordPage.parse(Object? value, {required bool paged}) {
    if (!paged) return RecordPage(records(value), null);
    final data = jsonObject(value);
    final next = data['next_offset'];
    if (next != null && (next is! int || next < 0 || next > 1000000)) {
      throw AppError.malformed();
    }
    return RecordPage(records(data['items']), next as int?);
  }
  final List<RecordData> items;
  final int? nextOffset;
}

const _integerFields = {
  'balance',
  'revision',
  'quantity',
  'baseline_quantity',
  'baseline_revision',
  'physical_quantity',
  'difference',
  'output_units',
  'version',
  'sale_count',
  'voided_count',
  'harvest_count',
  'plans_needing_review',
};
const _booleanFields = {
  'archived',
  'active',
  'reminders_enabled',
  'reminder_email',
  'reminder_due',
  'push_configured',
  'push_subscribed',
};
const _stringFields = {
  'status',
  'kind',
  'name',
  'email',
  'role',
  'sku',
  'description',
  'bio',
  'notes',
  'reason',
  'void_reason',
  'publication',
  'business_date',
  'created_at',
  'actor_name',
  'product_name',
  'product_name_snapshot',
  'farmer_name',
  'item_name',
  'channel',
  'external_ref',
  'name_snapshot',
  'movement_type',
  'action',
  'organization_name',
  'today',
  'timezone',
  'reminder_time',
  'village_title',
  'village_body',
  'shopee_url',
  'tokopedia_url',
  'whatsapp_url',
  'message',
};
Object? _freezeJson(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freezeJson(entry.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freezeJson));
  return value;
}

Object? _copyJson(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key as String: _copyJson(entry.value),
    };
  }
  if (value is List) return value.map(_copyJson).toList();
  return value;
}
