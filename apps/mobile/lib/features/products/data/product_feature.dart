import '../../../core/data/feature_spec.dart';
import '../../../core/network/json_data.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/forms/form_spec.dart';

List<FieldSpec> economicsFields([String prefix = '']) => [
  FieldSpec(
    '${prefix}material_g',
    'Kebutuhan kentang per unit',
    kind: InputKind.integer,
    unit: 'g',
    positive: true,
  ),
  FieldSpec(
    '${prefix}price_rp',
    'Harga jual per unit',
    kind: InputKind.integer,
    unit: 'Rp',
  ),
  FieldSpec(
    '${prefix}material_rp',
    'Biaya bahan per unit',
    kind: InputKind.integer,
    unit: 'Rp',
    optional: true,
  ),
  FieldSpec(
    '${prefix}packaging_rp',
    'Biaya kemasan per unit',
    kind: InputKind.integer,
    unit: 'Rp',
    optional: true,
  ),
  FieldSpec(
    '${prefix}production_rp',
    'Biaya produksi per unit',
    kind: InputKind.integer,
    unit: 'Rp',
    optional: true,
  ),
  FieldSpec(
    '${prefix}other_rp',
    'Biaya lain per unit',
    kind: InputKind.integer,
    unit: 'Rp',
    optional: true,
  ),
];
FormSpec productForm(FeatureBundle data, [RecordData? row]) => FormSpec(
  title: row == null ? 'Tambah produk' : 'Edit produk',
  path: '/products${row == null ? '' : '/${row.id}'}',
  method: row == null ? 'POST' : 'PUT',
  initial: row == null
      ? {'publication': 'DRAFT'}
      : {...row.json, 'whatsapp_url': whatsappNumber(row.s('whatsapp_url'))},
  description: row == null
      ? 'Kebutuhan fisik kentang dan biaya bahan adalah dua informasi yang berbeda.'
      : 'Untuk perubahan harga atau biaya, gunakan tombol Harga / HPP.',
  fields: [
    const FieldSpec('name', 'Nama produk'),
    const FieldSpec('sku', 'Kode produk', maxLength: 80),
    const FieldSpec(
      'description',
      'Deskripsi',
      kind: InputKind.textarea,
      optional: true,
      maxLength: 10000,
    ),
    const FieldSpec(
      'image_id',
      'Foto produk',
      kind: InputKind.image,
      optional: true,
    ),
    const FieldSpec(
      'publication',
      'Tampil di website',
      kind: InputKind.select,
      choices: publicationChoices,
    ),
    const FieldSpec(
      'shopee_url',
      'Tautan Shopee',
      optional: true,
      maxLength: 2048,
    ),
    const FieldSpec(
      'tokopedia_url',
      'Tautan Tokopedia',
      optional: true,
      maxLength: 2048,
    ),
    const FieldSpec(
      'whatsapp_url',
      'Nomor WhatsApp',
      optional: true,
      hint: 'Contoh: 081234567890',
      maxLength: 2048,
    ),
    if (row == null) ...economicsFields('economics.'),
  ],
  prepare: (v) => {
    ...v,
    'whatsapp_url': whatsappUrl(v['whatsapp_url'] as String),
  },
);
FormSpec economicsForm(RecordData row) => FormSpec(
  title: 'Perbarui harga & HPP',
  path: '/products/${row.id}/economics',
  initial: row.json,
  fields: economicsFields(),
  description: 'Harga dan biaya baru berlaku untuk transaksi berikutnya. Catatan transaksi lama tidak berubah.',
);
FormSpec gradeAForm(RecordData org) => FormSpec(
  title: 'Harga & HPP Grade A',
  path: '/organization/settings',
  method: 'PUT',
  initial: org.json,
  fields: const [
    FieldSpec(
      'grade_a_price_rp',
      'Harga Grade A per kg',
      kind: InputKind.integer,
      unit: 'Rp',
    ),
    FieldSpec(
      'grade_a_hpp_rp',
      'HPP Grade A per kg',
      kind: InputKind.integer,
      unit: 'Rp',
    ),
  ],
  prepare: (v) => settingsPayload(org, overrides: v),
);
Json settingsPayload(RecordData org, {Json overrides = const {}}) => {
  'name': org.s('name'),
  'timezone': org.s('timezone'),
  'reminder_time': org.s('reminder_time').substring(0, 5),
  'reminders_enabled': org.flag('reminders_enabled'),
  'reminder_email': org.flag('reminder_email'),
  'grade_a_price_rp': org.number('grade_a_price_rp'),
  'grade_a_hpp_rp': org.number('grade_a_hpp_rp'),
  ...overrides,
};
final productFeature = FeatureSpec(
  id: 'products',
  endpoint: '/products',
  title: 'Produk, harga & HPP',
  createLabel: 'Tambah produk',
  create: productForm,
  requiredStrings: ['id', 'name', 'sku', 'publication'],
  requiredIntegers: ['price_rp', 'hpp_rp', 'material_g', 'balance'],
  cells: (r) => [
    CellData('Produk', r.s('name'), secondary: [r.s('sku')]),
    CellData(
      'Harga / HPP per unit',
      money(r.number('price_rp')),
      secondary: ['HPP ${money(r.number('hpp_rp'))}'],
    ),
    CellData(
      'Bahan / stok',
      '${count(r.number('material_g'))} g per unit',
      secondary: ['${quantity(r.number('balance'), 'FINISHED')} tersedia'],
    ),
    CellData(
      'Publikasi',
      '',
      badge: r.archived ? 'Nonaktif' : r.s('publication'),
    ),
  ],
  actions: (r, data, user) => [
    if (!r.archived) RecordAction.form('Edit', productForm(data, r)),
    RecordAction.detail('Riwayat', DetailSpec('economics', r)),
    if (!r.archived) ...[
      RecordAction.form('Harga / HPP', economicsForm(r)),
      RecordAction.form(
        'Nonaktifkan',
        simpleForm(
          '/products/${r.id}/archive',
          'Nonaktifkan produk',
          'Produk berhenti tampil di website dan rencana aktifnya dibatalkan. Stok serta riwayat tetap disimpan.',
        ),
      ),
    ],
  ],
);
