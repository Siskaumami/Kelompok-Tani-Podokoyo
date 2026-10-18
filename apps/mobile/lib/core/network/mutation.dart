import 'dart:convert';
import 'dart:math';

import 'json_data.dart';

String uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Kept only in memory. A manual replay sends these exact bytes and key.
class PendingMutation {
  PendingMutation({
    required this.path,
    required this.method,
    required Json payload,
  }) : key = uuidV4(),
       encoded = jsonEncode(payload);
  final String path;
  final String method;
  final String key;
  final String encoded;
  Json get payload => jsonObject(jsonDecode(encoded));
}
