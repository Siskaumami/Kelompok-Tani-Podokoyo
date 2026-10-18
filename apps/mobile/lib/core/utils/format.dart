import 'package:intl/intl.dart';

const statusNames = <String, String>{
  'DRAFT': 'Draf',
  'FINALIZED': 'Final',
  'VOIDED': 'Dibatalkan',
  'COMPLETED': 'Selesai',
  'OPEN': 'Aktif',
  'CANCELLED': 'Dibatalkan',
  'NEEDS_REVIEW': 'Perlu ditinjau',
  'PUBLISHED': 'Terbit',
  'OWNER': 'Pengelola Utama',
  'ADMIN': 'Admin',
  'NO_SALES': 'Tidak ada penjualan',
  'OFFLINE': 'Offline',
  'WHATSAPP': 'WhatsApp',
  'SHOPEE': 'Shopee',
  'TOKOPEDIA': 'Tokopedia',
};
const reasonNames = <String, String>{
  'SHRINKAGE_OR_DAMAGE': 'Susut / rusak',
  'FAILED_PRODUCTION': 'Produksi gagal',
  'PREVIOUS_INPUT_ERROR': 'Kesalahan input sebelumnya',
  'UNRECORDED_SALE': 'Penjualan belum tercatat',
  'UNRECORDED_PRODUCTION': 'Produksi belum tercatat',
  'MISSING_GOODS': 'Barang hilang',
  'OTHER': 'Lainnya',
};

String integerInput(String raw, {bool positive = false}) {
  final value = raw.trim();
  if (!RegExp(r'^(0|[1-9]\d{0,12})$').hasMatch(value) ||
      BigInt.parse(value) > BigInt.from(1000000000000)) {
    throw const FormatException(
      'Ketik 1,5 atau 1.5 untuk 1,5 kg. Jangan gunakan pemisah ribuan.',
    );
  }
  if (positive && value == '0') {
    throw const FormatException('Jumlah harus lebih dari nol.');
  }
  return value;
}

String grams(String raw) {
  final value = raw.trim();
  final match = RegExp(r'^(\d+)(?:([,.])(\d{1,3}))?$').firstMatch(value);

  if (match == null) {
    throw const FormatException(
      'Jumlah kg maksimal tiga angka desimal. Ketik 1,5 atau 1.5 untuk 1,5 kg, tanpa pemisah ribuan.',
    );
  }

  final whole = match.group(1)!;
  final separator = match.group(2);
  final fraction = match.group(3) ?? '';

  if (separator == '.' && fraction.length == 3 && whole != '0') {
    throw const FormatException(
      'Titik dengan tiga angka di belakangnya bisa terbaca sebagai pemisah ribuan. Gunakan koma untuk tiga angka desimal.',
    );
  }

  return (BigInt.parse(whole) * BigInt.from(1000) +
          BigInt.parse(
            fraction.isEmpty ? '0' : fraction.padRight(3, '0'),
          ))
      .toString();
}

String kgInput(Object value) {
  final n = BigInt.parse('$value');
  final abs = n.abs();
  final remainder = (abs % BigInt.from(1000))
      .toString()
      .padLeft(3, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '${n.isNegative ? '-' : ''}${abs ~/ BigInt.from(1000)}${remainder.isEmpty ? '' : ',$remainder'}';
}

String count(Object value) {
  final n = BigInt.parse('$value');
  final text = n.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '${n.isNegative ? '-' : ''}$text';
}

String money(Object value) => 'Rp${count(value)}';
String quantity(Object value, String kind) {
  if (kind == 'FINISHED') return '${count(value)} unit';
  final n = BigInt.parse('$value');
  final parts = kgInput(n.abs()).split(',');
  return '${n.isNegative ? '-' : ''}${count(BigInt.parse(parts[0]))}${parts.length == 2 ? ',${parts[1]}' : ''} kg';
}

String shortDate(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? '—' : DateFormat('d MMM y', 'id_ID').format(date);
}

String timestamp(String value) {
  final date = DateTime.tryParse(value);
  return date == null
      ? '—'
      : '${DateFormat('d MMM y, HH:mm', 'id_ID').format(date.toUtc().add(const Duration(hours: 7)))} WIB';
}

String isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String validDate(String value) {
  final date = DateTime.tryParse(value);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      date == null ||
      isoDate(date) != value) {
    throw const FormatException('Tanggal tidak valid.');
  }
  return value;
}

String reasonLabel(String value) {
  final parts = value.split(':');
  final label = reasonNames[parts.first.trim()];
  if (label == null) return value;
  return parts.length > 1 ? '$label: ${parts.skip(1).join(':').trim()}' : label;
}

String whatsappNumber(String value) {
  if (value.isEmpty) return '';
  final url = Uri.tryParse(value);
  final digits =
      (value.startsWith('http')
              ? url?.host == 'wa.me'
                    ? url!.path
                    : url?.queryParameters['phone'] ?? ''
              : value)
          .replaceAll(RegExp(r'\D'), '');
  return digits.startsWith('62') ? '0${digits.substring(2)}' : digits;
}

String whatsappUrl(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) {
    digits = '62${digits.substring(1)}';
  } else if (digits.startsWith('8')) {
    digits = '62$digits';
  }
  return digits.isEmpty ? '' : 'https://wa.me/$digits';
}
