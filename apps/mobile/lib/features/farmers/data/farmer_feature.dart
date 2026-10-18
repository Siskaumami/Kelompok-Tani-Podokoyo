import '../../../core/data/feature_spec.dart';
import '../../../core/network/json_data.dart';
import '../../../core/widgets/forms/form_spec.dart';

FormSpec farmerForm(FeatureBundle data, [RecordData? row]) => FormSpec(
  title: row == null ? 'Tambah anggota tani' : 'Edit profil petani',
  path: '/farmers${row == null ? '' : '/${row.id}'}',
  method: row == null ? 'POST' : 'PUT',
  initial: row?.json ?? {'publication': 'DRAFT'},
  fields: const [
    FieldSpec('name', 'Nama petani'),
    FieldSpec(
      'publication',
      'Tampil di website',
      kind: InputKind.select,
      choices: publicationChoices,
    ),
    FieldSpec(
      'bio',
      'Profil singkat',
      kind: InputKind.textarea,
      optional: true,
      maxLength: 5000,
    ),
    FieldSpec('image_id', 'Foto profil', kind: InputKind.image, optional: true),
  ],
);
final farmerFeature = FeatureSpec(
  id: 'farmers',
  endpoint: '/farmers',
  title: 'Anggota kelompok tani',
  createLabel: 'Tambah anggota',
  create: farmerForm,
  requiredStrings: ['id', 'name', 'publication'],
  cells: (r) => [
    CellData('Anggota', r.s('name')),
    CellData('Profil', r.s('bio').isEmpty ? 'Belum diisi' : r.s('bio')),
    CellData(
      'Publikasi',
      '',
      badge: r.archived ? 'Nonaktif' : r.s('publication'),
    ),
  ],
  actions: (r, data, user) => [
    if (!r.archived) ...[
      RecordAction.form('Edit', farmerForm(data, r)),
      RecordAction.form(
        'Nonaktifkan',
        simpleForm(
          '/farmers/${r.id}/archive',
          'Nonaktifkan anggota',
          'Profil berhenti tampil di website. Catatan panen tetap disimpan.',
        ),
      ),
    ],
  ],
);
