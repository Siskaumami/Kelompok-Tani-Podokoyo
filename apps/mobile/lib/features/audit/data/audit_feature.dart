import '../../../core/data/feature_spec.dart';
import '../../../core/utils/format.dart';

import 'labels.dart';

final auditFeature = FeatureSpec(
  id: 'audit',
  endpoint: '/audit',
  title: 'Riwayat aktivitas',
  paged: true,
  requiredStrings: ['id', 'action', 'created_at'],
  cells: (r) => [
    CellData('Waktu', timestamp(r.s('created_at'))),
    CellData('Pelaku', r.s('actor_name', 'Sistem')),
    CellData(
      'Aktivitas',
      actionLabel(r.s('action')),
      secondary: [reasonLabel(r.s('reason'))],
    ),
  ],
  actions: (r, data, user) => [
    RecordAction.detail('Lihat perubahan', DetailSpec('audit', r)),
  ],
);
