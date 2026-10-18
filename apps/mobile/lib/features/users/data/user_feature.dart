import '../../../core/data/feature_spec.dart';
import '../../../core/network/json_data.dart';
import '../../../core/widgets/forms/form_spec.dart';

FormSpec invitationForm(FeatureBundle data) => const FormSpec(
  title: 'Undang Admin',
  path: '/users/invitations',
  description: 'Undangan dikirim melalui email. Penerima menentukan kata sandinya sendiri.',
  fields: [
    FieldSpec('name', 'Nama Admin'),
    FieldSpec('email', 'Email Admin', kind: InputKind.email, maxLength: 254),
  ],
);
FormSpec transferOwnerForm(RecordData row) => FormSpec(
  title: 'Pindahkan Owner',
  path: '/users/${row.id}/transfer-owner',
  description:
      'Akses Owner akan berpindah ke ${row.s('name')}. Akun Anda tetap aktif sebagai Admin. Masukkan kata sandi saat ini untuk mengonfirmasi.',
  fields: const [
    FieldSpec(
      'current_password',
      'Kata sandi saat ini',
      kind: InputKind.password,
      maxLength: 128,
    ),
  ],
  submitLabel: 'Pindahkan Owner',
  afterSave: AfterSave.verifySession,
);
final userFeature = FeatureSpec(
  id: 'users',
  endpoint: '/users',
  title: 'Pengguna',
  createLabel: 'Undang Admin',
  create: invitationForm,
  ownerCreate: true,
  requiredStrings: ['id', 'name', 'email', 'role'],
  cells: (r) => [
    CellData('Pengguna', r.s('name'), secondary: [r.s('email')]),
    CellData('Peran', '', badge: r.s('role')),
    CellData('Akses', '', badge: r.flag('active') ? 'Aktif' : 'Nonaktif'),
  ],
  actions: (r, data, user) => [
    if (user.isOwner && r.s('role') == 'ADMIN') ...[
      if (r.flag('active'))
        RecordAction.form('Jadikan Owner', transferOwnerForm(r)),
      RecordAction.form(
        r.flag('active') ? 'Nonaktifkan' : 'Aktifkan',
        FormSpec(
          title: r.flag('active') ? 'Nonaktifkan Admin' : 'Aktifkan Admin',
          path: '/users/${r.id}/active',
          method: 'PUT',
          description: r.flag('active')
              ? 'Semua sesi pengguna ini dicabut. Riwayat aktivitas tetap tersedia.'
              : 'Akun kembali dapat masuk menggunakan kata sandinya.',
          prepare: (_) => {'active': !r.flag('active')},
        ),
      ),
    ],
  ],
);
