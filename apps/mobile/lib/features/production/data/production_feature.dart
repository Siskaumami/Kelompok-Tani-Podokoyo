import '../../../core/data/feature_spec.dart';
import '../../../core/network/json_data.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/forms/form_spec.dart';

FormSpec productionForm(FeatureBundle data, [RecordData? plan]) => FormSpec(
  title: plan == null ? 'Catat hasil produksi' : 'Catat hasil dari rencana',
  path: '/production/batches',
  initial: {
    'business_date': data.today,
    if (plan != null) 'actual_g': plan.number('planned_g'),
  },
  description: plan == null
      ? 'Masukkan jumlah kentang yang benar-benar dipakai dan produk yang benar-benar dihasilkan.'
      : 'Jumlah kentang yang dipakai boleh berbeda dari rencana. Rencana akan selesai setelah hasil produksi disimpan.',
  fields: [
    if (plan == null)
      FieldSpec(
        'product_id',
        'Produk',
        kind: InputKind.select,
        choices: data.activeProducts(),
      ),
    const FieldSpec('business_date', 'Tanggal produksi', kind: InputKind.date),
    const FieldSpec(
      'actual_g',
      'Grade B benar-benar dipakai',
      kind: InputKind.kg,
      positive: true,
      unit: 'kg',
    ),
    const FieldSpec(
      'output_units',
      'Produk jadi yang dihasilkan',
      kind: InputKind.integer,
      positive: true,
      unit: 'unit',
    ),
    const FieldSpec(
      'notes',
      'Catatan proses / selisih',
      kind: InputKind.textarea,
      optional: true,
      maxLength: 2000,
    ),
  ],
  prepare: (v) => {
    ...v,
    if (plan != null) ...{
      'product_id': plan.s('product_id'),
      'plan_id': plan.id,
    },
  },
);
final productionFeature = FeatureSpec(
  id: 'production',
  endpoint: '/production/batches',
  title: 'Hasil produksi',
  paged: true,
  lookups: ['products'],
  createLabel: 'Catat produksi',
  create: productionForm,
  notice: 'Catat hasil fisik sebenarnya. Rencana lain yang tidak lagi tertutup stok akan ditandai Perlu ditinjau.',
  requiredStrings: ['id', 'business_date', 'status', 'product_name_snapshot'],
  requiredIntegers: ['actual_g', 'output_units', 'theoretical_g', 'variance_g'],
  cells: (r) => [
    CellData(
      'Tanggal / produk',
      shortDate(r.s('business_date')),
      secondary: [r.s('product_name_snapshot')],
    ),
    CellData('Bahan dipakai', quantity(r.number('actual_g'), 'GRADE_B')),
    CellData(
      'Hasil / selisih',
      '${count(r.number('output_units'))} unit',
      secondary: [
        'Perkiraan kebutuhan ${quantity(r.number('theoretical_g'), 'GRADE_B')}',
        'Selisih ${quantity(r.number('variance_g'), 'GRADE_B')}',
      ],
    ),
    CellData('Status', '', badge: r.status),
  ],
  actions: (r, data, user) => [
    if (r.status == 'COMPLETED')
      RecordAction.form(
        'Batalkan',
        reasonForm(
          '/production/batches/${r.id}/void',
          'Batalkan produksi',
          'Produk hasil produksi harus masih tersedia agar pembatalan dapat dilakukan. Bahan yang dipakai akan dikembalikan ke stok tercatat.',
        ),
      ),
  ],
);
