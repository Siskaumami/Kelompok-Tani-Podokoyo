import '../../../core/data/feature_spec.dart';
import '../../../core/utils/format.dart';

final inventoryFeature = FeatureSpec(
  id: 'inventory',
  endpoint: '/inventory',
  title: 'Persediaan',
  refreshSeconds: 20,
  requiredStrings: ['id', 'name', 'kind'],
  requiredIntegers: ['balance', 'planned_g'],
  cells: (r) => [
    CellData(
      'Barang',
      r.s('name'),
      secondary: [r.kind == 'FINISHED' ? 'Produk jadi' : 'Bahan baku'],
    ),
    CellData('Stok tercatat', quantity(r.number('balance'), r.kind)),
    CellData(
      'Sudah direncanakan',
      r.kind == 'GRADE_B' ? quantity(r.number('planned_g'), r.kind) : '—',
      secondary: r.kind == 'GRADE_B'
          ? [
              'Belum direncanakan ${quantity(BigInt.parse(r.number('balance')) - BigInt.parse(r.number('planned_g')), r.kind)}',
            ]
          : [],
    ),
  ],
  actions: (r, data, user) => [
    RecordAction.detail('Lihat riwayat stok', DetailSpec('ledger', r)),
  ],
);
