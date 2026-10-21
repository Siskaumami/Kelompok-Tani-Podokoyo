import 'package:flutter/foundation.dart';

import '../../../core/network/json_data.dart';
import '../../../core/utils/format.dart';

class SaleDraftLine {
  SaleDraftLine({this.itemId = '', this.quantity = '', this.price = ''});
  String itemId;
  String quantity;
  String price;
  final key = UniqueKey();
}

Json saleLinePayload(SaleDraftLine line, List<RecordData> inventory) {
  final item = inventory.where((i) => i.id == line.itemId).firstOrNull;
  if (item == null) {
    throw const FormatException('Pilih barang yang terjual.');
  }
  return {
    'item_id': item.id,
    'quantity': integerInput(
      item.kind != 'FINISHED' ? grams(line.quantity) : line.quantity,
      positive: true,
    ),
    if (line.price.trim().isNotEmpty) 'unit_price_rp': integerInput(line.price),
  };
}
