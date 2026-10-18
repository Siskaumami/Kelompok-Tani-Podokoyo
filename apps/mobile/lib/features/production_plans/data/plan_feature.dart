import '../../../core/data/feature_spec.dart';
import '../../../core/network/json_data.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/forms/form_spec.dart';

import '../../production/data/production_feature.dart';

FormSpec planForm(FeatureBundle data, [RecordData? row]) => FormSpec(
  title: row == null ? 'Buat rencana produksi' : 'Ubah rencana',
  path: '/production/plans${row == null ? '' : '/${row.id}'}',
  method: row == null ? 'POST' : 'PUT',
  initial: row?.json ?? {'business_date': data.today},
  fields: [
    FieldSpec(
      'product_id',
      'Produk tujuan',
      kind: InputKind.select,
      choices: data.activeProducts(),
    ),
    const FieldSpec('business_date', 'Tanggal rencana', kind: InputKind.date),
    const FieldSpec(
      'planned_g',
      'Jumlah Grade B yang direncanakan',
      kind: InputKind.kg,
      positive: true,
      unit: 'kg',
    ),
    const FieldSpec(
      'notes',
      'Catatan',
      kind: InputKind.textarea,
      optional: true,
      maxLength: 2000,
    ),
  ],
);
final planFeature = FeatureSpec(
  id: 'plans',
  endpoint: '/production/plans',
  title: 'Rencana produksi',
  paged: true,
  lookups: ['products'],
  createLabel: 'Buat rencana',
  create: planForm,
  refreshSeconds: 20,
  notice: 'Rencana ini hanya mencatat kebutuhan produksi.',
  requiredStrings: [
    'id',
    'product_id',
    'product_name',
    'business_date',
    'status',
  ],
  requiredIntegers: ['planned_g'],
  cells: (r) => [
    CellData('Tanggal', shortDate(r.s('business_date'))),
    CellData('Produk tujuan', r.s('product_name')),
    CellData(
      'Grade B direncanakan',
      quantity(r.number('planned_g'), 'GRADE_B'),
    ),
    CellData('Status', '', badge: r.status),
  ],
  actions: (r, data, user) => [
    if (['OPEN', 'NEEDS_REVIEW'].contains(r.status)) ...[
      RecordAction.form('Ubah', planForm(data, r)),
      RecordAction.form('Catat hasil', productionForm(data, r)),
      RecordAction.form(
        'Batalkan',
        reasonForm(
          '/production/plans/${r.id}/cancel',
          'Batalkan rencana',
          'Pembatalan rencana membatalkan jumlah yang direncanakan tanpa mengubah stok fisik.',
        ),
      ),
    ],
  ],
);
