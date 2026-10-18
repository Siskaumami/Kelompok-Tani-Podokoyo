import '../auth/session.dart';
import '../network/json_data.dart';
import '../widgets/forms/form_spec.dart';

class CellData {
  const CellData(
    this.label,
    this.primary, {
    this.secondary = const [],
    this.badge,
    this.informational = false,
  });
  final String label;
  final String primary;
  final List<String> secondary;
  final String? badge;
  final bool informational;
}

class DetailSpec {
  const DetailSpec(this.type, this.row);
  final String type;
  final RecordData row;
}

class RecordAction {
  const RecordAction.form(this.label, FormSpec spec)
    : form = spec,
      detail = null;
  const RecordAction.detail(this.label, DetailSpec spec)
    : detail = spec,
      form = null;
  final String label;
  final FormSpec? form;
  final DetailSpec? detail;
}

class FeatureBundle {
  const FeatureBundle({
    required this.page,
    required this.organization,
    required this.today,
    this.lookups = const {},
    this.notifications,
  });
  final RecordPage page;
  final RecordData organization;
  final String today;
  final Map<String, List<RecordData>> lookups;
  final RecordData? notifications;
  List<RecordData> rows(String key) => lookups[key] ?? const [];
  List<Choice> activeProducts() =>
      rows('products')
          .where((p) => !p.archived)
          .map((p) => Choice(p.id, p.s('name')))
          .toList(growable: false);
}

class FeatureSpec {
  const FeatureSpec({
    required this.id,
    required this.endpoint,
    required this.title,
    required this.cells,
    required this.actions,
    this.paged = false,
    this.lookups = const [],
    this.createLabel,
    this.create,
    this.ownerCreate = false,
    this.notice,
    this.refreshSeconds,
    this.requiredStrings = const ['id'],
    this.requiredIntegers = const [],
  });
  final String id;
  final String endpoint;
  final String title;
  final bool paged;
  final List<String> lookups;
  final String? createLabel;
  final FormSpec Function(FeatureBundle data)? create;
  final bool ownerCreate;
  final String? notice;
  final int? refreshSeconds;
  final List<String> requiredStrings;
  final List<String> requiredIntegers;
  final List<CellData> Function(RecordData row) cells;
  final List<RecordAction> Function(
    RecordData row,
    FeatureBundle data,
    SessionUser user,
  )
  actions;
}
