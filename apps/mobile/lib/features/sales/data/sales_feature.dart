import '../../../core/data/feature_spec.dart';
import '../../../core/network/json_data.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/forms/form_spec.dart';

final saleFeature = FeatureSpec(
  id: 'sales',
  endpoint: '/sales',
  title: 'Penjualan',
  paged: true,
  lookups: ['inventory', 'products'],
  createLabel: 'Catat penjualan',
  requiredStrings: ['id', 'business_date', 'channel', 'status'],
  requiredIntegers: ['net_rp'],
  cells: (r) => [
    CellData(
      'Tanggal / pesanan',
      shortDate(r.s('business_date')),
      secondary: [
        r.s('external_ref').isEmpty
            ? 'Tidak ada nomor pesanan'
            : r.s('external_ref'),
      ],
    ),
    CellData('Tempat penjualan', '', badge: r.s('channel')),
    CellData('Pendapatan bersih', money(r.number('net_rp'))),
    CellData('Status', '', badge: r.status),
  ],
  actions: (r, data, user) => [
    RecordAction.detail('Rincian', DetailSpec('sale', r)),
    if (r.status == 'COMPLETED')
      RecordAction.form(
        'Batalkan',
        reasonForm(
          '/sales/${r.id}/void',
          'Batalkan penjualan',
          'Stok dikembalikan dan laporan periode asal diperbarui. Alasan serta transaksi asal tetap disimpan.',
        ),
      ),
  ],
);
FormSpec salesConfirmation(RecordData notification, String status) =>
    simpleForm(
      '/sales-day/confirm',
      status == 'COMPLETED'
          ? 'Konfirmasi pencatatan'
          : 'Tidak ada penjualan hari ini',
      status == 'COMPLETED'
          ? 'Pengingat tanggal ini dihentikan. Ini bukan penutupan buku.'
          : 'Konfirmasi hanya dapat disimpan jika belum ada penjualan aktif pada tanggal ini.',
      initial: {
        'business_date': notification.s('business_date'),
        'status': status,
      },
    );
