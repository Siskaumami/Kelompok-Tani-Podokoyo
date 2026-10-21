import '../../../core/auth/auth_controller.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/network/json_data.dart';
import '../../../core/utils/format.dart';

const reportLabels = <String, String>{
  'grade_a_gross_rp': 'Penjualan Grade A',
  'grade_b_gross_rp': 'Penjualan Grade B mentah',
  'finished_gross_rp': 'Penjualan produk jadi',
  'gross_rp': 'Pendapatan kotor',
  'discount_rp': 'Diskon',
  'fee_rp': 'Biaya marketplace',
  'net_rp': 'Pendapatan bersih',
  'hpp_rp': 'HPP',
  'profit_rp': 'Estimasi laba kotor',
};
void validatePeriod(String from, String to) {
  validDate(from);
  validDate(to);
  if (from.compareTo(to) > 0 ||
      DateTime.parse('${to}T00:00:00Z')
              .difference(DateTime.parse('${from}T00:00:00Z'))
              .inDays >
          366) {
    throw const AppError(
      'Pilih rentang laporan paling lama 367 hari.',
      code: 'REPORT_RANGE',
      status: 422,
    );
  }
}

class ReportData {
  ReportData(Object? value) : data = RecordData(value) {
    totals.validate(
      integers: [...reportLabels.keys, 'sale_count', 'voided_count'],
    );
    for (final row in transactions) {
      row.validate(
        strings: ['id', 'business_date', 'channel', 'status'],
        integers: ['net_rp', 'hpp_rp'],
      );
    }
  }
  final RecordData data;
  RecordData get totals => data.object('totals');
  List<RecordData> get transactions => data.rows('transactions');
}

final reportProvider = FutureProvider.autoDispose
    .family<ReportData, (String, String)>((ref, period) async {
      ref.watch(dataEpochProvider);
      requireAuthenticated(ref);
      validatePeriod(period.$1, period.$2);
      final data = await ref
          .watch(apiProvider)
          .get('/reports?from=${period.$1}&to=${period.$2}');
      return ReportData(data);
    });
