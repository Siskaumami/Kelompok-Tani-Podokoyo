import '../../../core/data/feature_spec.dart';
import '../../../core/network/json_data.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/forms/form_spec.dart';

BigInt physicalCount(RecordData row, Json values) => BigInt.parse(
  row.kind == 'FINISHED'
      ? integerInput((values['physical_quantity'] ?? '').toString())
      : grams((values['physical_quantity'] ?? '').toString()),
);
bool matchingCount(RecordData row, Json values) {
  try {
    return physicalCount(row, values) ==
        BigInt.parse(row.number('baseline_quantity'));
  } on FormatException {
    return false;
  }
}

FormSpec completeOpnameForm(RecordData row) => FormSpec(
  title: 'Selesaikan cek stok',
  path: '/opnames/${row.id}/complete',
  description:
      'Stok tercatat saat mulai: ${quantity(row.number('baseline_quantity'), row.kind)}. Jika ada transaksi lain selama Anda menghitung, gunakan stok terbaru lalu hitung kembali.',
  fields: [
    FieldSpec(
      'physical_quantity',
      'Stok fisik yang dihitung',
      kind: row.kind == 'FINISHED' ? InputKind.integer : InputKind.kg,
      unit: row.kind == 'FINISHED' ? 'unit' : 'kg',
    ),
    FieldSpec(
      'reason',
      'Alasan selisih',
      kind: InputKind.select,
      optional: true,
      choices: reasonChoices,
      enabled: (v) => !matchingCount(row, v),
    ),
    const FieldSpec(
      'notes',
      'Keterangan',
      kind: InputKind.textarea,
      optional: true,
      maxLength: 2000,
    ),
  ],
  normalize: (v) {
    if (matchingCount(row, v)) v['reason'] = '';
  },
  prepare: (v) {
    final same =
        BigInt.parse(v['physical_quantity'] as String) ==
        BigInt.parse(row.number('baseline_quantity'));
    if (same) {
      v['reason'] = null;
    } else if (v['reason'] == null || v['reason'] == '') {
      throw const FormatException('Pilih alasan selisih sebelum menyimpan.');
    }
    if (v['reason'] == 'OTHER' && (v['notes'] as String).isEmpty) {
      throw const FormatException('Isi keterangan untuk alasan Lainnya.');
    }
    return v;
  },
  summary: (v) {
    try {
      return 'Selisih ${quantity(physicalCount(row, v) - BigInt.parse(row.number('baseline_quantity')), row.kind)}';
    } on FormatException {
      return null;
    }
  },
);
FormSpec startOpnameForm(FeatureBundle data) => FormSpec(
  title: 'Mulai cek stok',
  path: '/opnames',
  description: 'Jumlah stok saat ini akan dicatat. Setelah menghitung barang yang ada, masukkan hasil hitungnya.',
  fields: [
    FieldSpec(
      'item_id',
      'Barang yang diperiksa',
      kind: InputKind.select,
      choices: data
          .rows('inventory')
          .map(
            (r) => Choice(
              r.id,
              '${r.s('name')} · ${quantity(r.number('balance'), r.kind)}',
            ),
          )
          .toList(),
    ),
  ],
);
final opnameFeature = FeatureSpec(
  id: 'opnames',
  endpoint: '/opnames',
  title: 'Cek stok fisik',
  paged: true,
  lookups: ['inventory'],
  createLabel: 'Mulai pemeriksaan',
  create: startOpnameForm,
  refreshSeconds: 20,
  requiredStrings: ['id', 'item_id', 'item_name', 'kind', 'status'],
  requiredIntegers: ['baseline_quantity', 'baseline_revision'],
  cells: (r) => [
    CellData(
      'Barang',
      r.s('item_name'),
      secondary: [timestamp(r.s('created_at'))],
    ),
    CellData('Stok tercatat', quantity(r.number('baseline_quantity'), r.kind)),
    CellData(
      'Fisik / selisih',
      r['physical_quantity'] == null
          ? 'Belum diselesaikan'
          : quantity(r.number('physical_quantity'), r.kind),
      secondary: r['physical_quantity'] == null
          ? []
          : ['Selisih ${quantity(r.number('difference'), r.kind)}'],
    ),
    CellData('Status', '', badge: r.status),
    if (r.status == 'COMPLETED')
      CellData(
        'Tindakan',
        r.number('difference') == '0'
            ? 'Sesuai'
            : reasonNames[r.s('reason')] ?? r.s('reason'),
        secondary: [if (r.s('notes').isNotEmpty) r.s('notes')],
        informational: true,
      ),
  ],
  actions: (r, data, user) => [
    if (r.status == 'OPEN') ...[
      RecordAction.form('Isi hasil hitung', completeOpnameForm(r)),
      RecordAction.form(
        'Gunakan stok terbaru',
        simpleForm(
          '/opnames/${r.id}/refresh',
          'Gunakan stok terbaru',
          'Stok tercatat akan diperbarui. Setelah itu, hitung kembali jumlah barang yang ada.',
        ),
      ),
      RecordAction.form(
        'Batalkan',
        reasonForm(
          '/opnames/${r.id}/cancel',
          'Batalkan cek stok',
          'Tidak ada penyesuaian stok yang dibuat.',
        ),
      ),
    ],
  ],
);
