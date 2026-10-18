import '../../../core/data/feature_spec.dart';
import '../../../core/network/json_data.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/forms/form_spec.dart';

FormSpec harvestForm(FeatureBundle data, [RecordData? row]) => FormSpec(
  title: row == null ? 'Catat panen' : 'Edit panen',
  path: '/harvests${row == null ? '' : '/${row.id}'}',
  method: row == null ? 'POST' : 'PUT',
  initial: row?.json ?? {'business_date': data.today},
  description: 'Data bisa disimpan sebelum sortir selesai. Selesaikan panen setelah semua hasil sudah dibagi ke Grade A, Grade B, dan afkir.',
  fields: [
    const FieldSpec('business_date', 'Tanggal panen', kind: InputKind.date),
    FieldSpec(
      'farmer_id',
      'Petani',
      kind: InputKind.select,
      optional: true,
      choices: data
          .rows('farmers')
          .where((r) => !r.archived)
          .map((r) => Choice(r.id, r.s('name')))
          .toList(),
    ),
    const FieldSpec(
      'total_g',
      'Total panen',
      kind: InputKind.kg,
      positive: true,
      unit: 'kg',
    ),
    const FieldSpec(
      'grade_a_g',
      'Grade A',
      kind: InputKind.kg,
      optional: true,
      unit: 'kg',
    ),
    const FieldSpec(
      'grade_b_g',
      'Grade B',
      kind: InputKind.kg,
      optional: true,
      unit: 'kg',
    ),
    const FieldSpec(
      'reject_g',
      'Afkir / susut',
      kind: InputKind.kg,
      optional: true,
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
  prepare: (v) {
    v['farmer_id'] = v['farmer_id'] == '' ? null : v['farmer_id'];
    final classified =
        BigInt.parse(v['grade_a_g'] as String) +
        BigInt.parse(v['grade_b_g'] as String) +
        BigInt.parse(v['reject_g'] as String);
    if (classified > BigInt.parse(v['total_g'] as String)) {
      throw const FormatException('Jumlah hasil sortir melebihi total panen.');
    }
    return v;
  },
  summary: (v) {
    try {
      final left =
          BigInt.parse(grams(v['total_g'] as String)) -
          ['grade_a_g', 'grade_b_g', 'reject_g']
              .map(
                (k) => BigInt.parse(grams(v[k] == '' ? '0' : v[k] as String)),
              )
              .fold(BigInt.zero, (a, b) => a + b);
      return 'Belum dibagi ${quantity(left, 'GRADE_A')}';
    } on FormatException {
      return null;
    }
  },
);
final harvestFeature = FeatureSpec(
  id: 'harvests',
  endpoint: '/harvests',
  title: 'Panen & sortir',
  paged: true,
  lookups: ['farmers'],
  createLabel: 'Catat panen',
  create: harvestForm,
  requiredStrings: ['id', 'status', 'business_date'],
  requiredIntegers: [
    'total_g',
    'grade_a_g',
    'grade_b_g',
    'reject_g',
    'remaining_g',
  ],
  cells: (r) => [
    CellData(
      'Tanggal / petani',
      shortDate(r.s('business_date')),
      secondary: [r.s('farmer_name', 'Tidak dihubungkan ke petani')],
    ),
    CellData('Total panen', quantity(r.number('total_g'), 'GRADE_A')),
    CellData(
      'Hasil sortir',
      'A ${quantity(r.number('grade_a_g'), 'GRADE_A')}',
      secondary: [
        'B ${quantity(r.number('grade_b_g'), 'GRADE_B')} · Afkir ${quantity(r.number('reject_g'), 'GRADE_A')}',
        if (r.status == 'DRAFT')
          'Sisa ${quantity(r.number('remaining_g'), 'GRADE_A')}',
      ],
    ),
    CellData('Status', '', badge: r.status),
  ],
  actions: (r, data, user) => [
    if (r.status == 'DRAFT') ...[
      RecordAction.form('Edit', harvestForm(data, r)),
      RecordAction.form(
        'Selesaikan',
        simpleForm(
          '/harvests/${r.id}/finalize',
          'Selesaikan panen',
          'Hasil Grade A dan Grade B akan masuk ke persediaan setelah panen diselesaikan.',
        ),
      ),
    ],
    if (r.status == 'FINALIZED')
      RecordAction.form(
        'Batalkan',
        reasonForm(
          '/harvests/${r.id}/void',
          'Batalkan panen',
          'Stok harus cukup untuk membalikkan hasil panen ini. Catat panen pengganti setelah pembatalan.',
        ),
      ),
  ],
);
