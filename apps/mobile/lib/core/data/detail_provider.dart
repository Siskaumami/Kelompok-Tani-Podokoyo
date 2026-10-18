import '../auth/auth_controller.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../network/json_data.dart';

class DetailData {
  const DetailData({this.object, this.rows = const [], this.next});
  final RecordData? object;
  final List<RecordData> rows;
  final int? next;
}

final detailProvider = FutureProvider.autoDispose
    .family<DetailData, (String, String, int)>((ref, key) async {
      ref.watch(dataEpochProvider);
      requireAuthenticated(ref);
      final repo = ref.watch(repositoryProvider);
      switch (key.$1) {
        case 'sale':
          return DetailData(object: await repo.object('/sales/${key.$2}'));
        case 'economics':
          return DetailData(
            rows: await repo.list('/products/${key.$2}/history'),
          );
        case 'ledger':
          final page = await repo.page(
            '/inventory/${key.$2}/movements',
            paged: true,
            offset: key.$3,
          );
          return DetailData(rows: page.items, next: page.nextOffset);
        default:
          throw const FormatException('Rincian tidak tersedia.');
      }
    });
