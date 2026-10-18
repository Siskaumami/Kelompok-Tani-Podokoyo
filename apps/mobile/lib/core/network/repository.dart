import 'package:dio/dio.dart';

import 'api_client.dart';
import 'json_data.dart';
import 'mutation.dart';
import '../utils/format.dart';

/// The shared read adapter keeps envelope and parser handling out of screens.
class Repository {
  const Repository(this.api);
  final ApiClient api;
  Future<RecordData> object(String path, {CancelToken? cancelToken}) async {
    final value = RecordData(await api.get(path, cancelToken: cancelToken));
    if (path == '/organization') {
      value.validate(
        strings: ['id', 'name', 'timezone', 'reminder_time', 'publication'],
        integers: ['grade_a_price_rp', 'grade_a_hpp_rp'],
      );
      if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d')
          .hasMatch(value.s('reminder_time'))) {
        throw const FormatException('Jam pengingat tidak valid.');
      }
    } else if (path == '/notifications') {
      value.validate(strings: ['business_date', 'timezone', 'reminder_time']);
      validDate(value.s('business_date'));
      if (value['confirmation'] != null) {
        value
            .object('confirmation')
            .validate(strings: ['status', 'business_date']);
      }
    } else if (path == '/overview') {
      value.validate(strings: ['organization_name', 'today']);
      validDate(value.s('today'));
      value
          .object('counts')
          .validate(
            integers: ['harvest_count', 'sale_count', 'plans_needing_review'],
          );
      value.object('today_sales').validate(integers: ['sale_count', 'net_rp']);
      for (final row in value.rows('inventory')) {
        row.validate(
          strings: ['id', 'name', 'kind'],
          integers: ['balance', 'planned_g'],
        );
      }
    } else if (path.startsWith('/sales/')) {
      value.validate(
        strings: ['id', 'business_date', 'channel', 'status'],
        integers: ['gross_rp', 'discount_rp', 'fee_rp', 'net_rp', 'hpp_rp'],
      );
      for (final row in value.rows('items')) {
        row.validate(
          strings: ['kind', 'name_snapshot'],
          integers: ['quantity', 'unit_price_rp', 'gross_rp'],
        );
      }
    }
    return value;
  }

  Future<List<RecordData>> list(
    String path, {
    CancelToken? cancelToken,
  }) async => records(await api.get(path, cancelToken: cancelToken));
  Future<RecordPage> page(
    String path, {
    required bool paged,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    final data = await api.get(
      paged ? '$path?limit=30&offset=$offset' : path,
      cancelToken: cancelToken,
    );
    return RecordPage.parse(data, paged: paged);
  }

  Future<Object?> save(PendingMutation mutation) => api.mutate(mutation);
}
