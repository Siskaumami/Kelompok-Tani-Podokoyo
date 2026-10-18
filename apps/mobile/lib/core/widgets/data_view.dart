import 'package:flutter/material.dart';

import '../network/json_data.dart';
import '../utils/format.dart';
import 'common.dart';

const dataLabels = <String, String>{
  'name': 'Nama',
  'status': 'Status',
  'price_rp': 'Harga jual',
  'hpp_rp': 'HPP',
  'material_g': 'Kebutuhan bahan (g)',
  'material_rp': 'Biaya bahan',
  'packaging_rp': 'Biaya kemasan',
  'production_rp': 'Biaya produksi',
  'other_rp': 'Biaya lain',
  'business_date': 'Tanggal',
  'grade_a_g': 'Grade A (g)',
  'grade_b_g': 'Grade B (g)',
  'reject_g': 'Afkir (g)',
  'total_g': 'Total panen (g)',
  'actual_g': 'Pemakaian nyata (g)',
  'output_units': 'Hasil (unit)',
  'theoretical_g': 'Perkiraan kebutuhan (g)',
  'planned_g': 'Jumlah direncanakan (g)',
  'notes': 'Catatan',
  'reason': 'Alasan',
  'publication': 'Publikasi',
  'balance': 'Stok',
  'physical_quantity': 'Jumlah fisik',
  'baseline_quantity': 'Stok tercatat',
  'difference': 'Selisih',
  'active': 'Akses aktif',
  'gross_rp': 'Pendapatan kotor',
  'net_rp': 'Pendapatan bersih',
  'discount_rp': 'Diskon',
  'fee_rp': 'Biaya',
  'email': 'Email',
  'sku': 'Kode produk',
};

class DataView extends StatelessWidget {
  const DataView(this.value, {super.key, this.depth = 0});
  final Object? value;
  final int depth;
  @override
  Widget build(BuildContext context) {
    if (value == null) return const Text('Belum ada catatan sebelumnya.');
    if (depth > 8) return const Text('Rincian terlalu panjang.');
    if (value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in (value as List).take(100))
            DataView(row, depth: depth + 1),
        ],
      );
    }
    if (value is! Map) return Text('$value');
    final data = jsonObject(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in data.entries.where(
          (e) =>
              !e.key.endsWith('_id') &&
              !['id', 'created_by', 'changed_by'].contains(e.key) &&
              !RegExp(
                'password|token|csrf|cookie|secret',
                caseSensitive: false,
              ).hasMatch(e.key),
        ))
          if (entry.value is Map || entry.value is List)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dataLabels[entry.key] ?? entry.key.replaceAll('_', ' ')),
                  DataView(entry.value, depth: depth + 1),
                ],
              ),
            )
          else
            KeyValue(
              dataLabels[entry.key] ?? entry.key.replaceAll('_', ' '),
              _display(entry.key, entry.value),
            ),
      ],
    );
  }

  String _display(String key, Object? value) {
    if (value == null) return '—';
    if (value is bool) return value ? 'Ya' : 'Tidak';
    if (key.endsWith('_rp')) {
      try {
        return money('$value');
      } on FormatException {
        return '—';
      }
    }
    return statusNames['$value'] ?? '$value';
  }
}
