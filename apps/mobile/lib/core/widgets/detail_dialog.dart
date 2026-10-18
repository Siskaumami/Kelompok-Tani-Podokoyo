import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/audit/data/labels.dart';
import '../data/detail_provider.dart';
import '../data/feature_spec.dart';
import '../network/json_data.dart';
import '../utils/format.dart';
import 'common.dart';
import 'data_view.dart';
import 'record_list.dart';

Future<void> showRecordDetail(BuildContext context, DetailSpec detail) =>
    showDialog<void>(
      context: context,
      builder: (_) => DetailDialog(detail: detail),
    );

class DetailDialog extends ConsumerStatefulWidget {
  const DetailDialog({super.key, required this.detail});
  final DetailSpec detail;
  @override
  ConsumerState<DetailDialog> createState() => _DetailDialogState();
}

class _DetailDialogState extends ConsumerState<DetailDialog> {
  int offset = 0;
  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final title = switch (detail.type) {
      'sale' => 'Rincian penjualan',
      'ledger' => 'Riwayat stok · ${detail.row.s('name')}',
      'economics' => 'Riwayat harga & HPP',
      _ => 'Rincian aktivitas',
    };
    final key = (detail.type, detail.row.id, offset);
    final phone = MediaQuery.sizeOf(context).width <= 640;
    return Dialog(
      insetPadding: EdgeInsets.all(phone ? 10 : 12),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xffd2e1d6)),
        borderRadius: BorderRadius.circular(phone ? 13 : 16),
      ),
      child: SizedBox(
        width: 760,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height - (phone ? 20 : 40),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  phone ? 18 : 20,
                  14,
                  phone ? 8 : 10,
                  10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(phone ? 18 : 20),
                  child: detail.type == 'audit'
                      ? _audit(detail.row)
                      : ref
                            .watch(detailProvider(key))
                            .when(
                              data: (data) =>
                                  _body(detail.type, detail.row, data),
                              loading: () => const Loading(),
                              error: (error, stack) => ErrorNotice(
                                error,
                                retry: () =>
                                    ref.invalidate(detailProvider(key)),
                              ),
                            ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  phone ? 19 : 16,
                  phone ? 18 : 16,
                  phone ? 19 : 16,
                  phone ? 18 : 16,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _audit(RecordData row) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        actionLabel(row.s('action')),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      Text(
        '${row.s('actor_name', 'Sistem')} · ${timestamp(row.s('created_at'))}',
      ),
      if (row.s('reason').isNotEmpty) Notice(reasonLabel(row.s('reason'))),
      const SizedBox(height: 16),
      const Text('Sebelum', style: TextStyle(fontWeight: FontWeight.w600)),
      DataView(row['before_data']),
      const Divider(),
      const Text('Sesudah', style: TextStyle(fontWeight: FontWeight.w600)),
      DataView(row['after_data']),
    ],
  );
  Widget _body(String type, RecordData row, DetailData data) {
    if (type == 'sale') return _sale(data.object!);
    if (type == 'economics') {
      return Column(
        children: [
          for (final v in data.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Versi ${v.number('version')}'),
                    Text(timestamp(v.s('created_at'))),
                    const SizedBox(height: 12),
                    KeyValue('Harga jual', money(v.number('price_rp'))),
                    KeyValue('HPP', money(v.number('hpp_rp'))),
                    Text('Bahan ${count(v.number('material_g'))} g / unit'),
                    Text(
                      'Biaya bahan ${money(v.number('material_rp'))} · kemasan ${money(v.number('packaging_rp'))} · produksi ${money(v.number('production_rp'))} · lainnya ${money(v.number('other_rp'))}',
                    ),
                    if (v.s('reason').isNotEmpty) Text(v.s('reason')),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    return Column(
      children: [
        RecordList(
          rows: data.rows,
          empty: 'Belum ada pergerakan stok',
          cells: (r) => [
            CellData('Waktu', timestamp(r.s('created_at'))),
            CellData(
              'Kegiatan',
              movementNames[r.s('movement_type')] ?? r.s('movement_type'),
              secondary: [
                '${r.s('actor_name')} · ${reasonLabel(r.s('reason'))}',
              ],
            ),
            CellData(
              'Perubahan',
              '${BigInt.parse(r.number('delta')) > BigInt.zero ? '+' : ''}${quantity(r.number('delta'), row.kind)}',
            ),
          ],
          actions: (_) => const [],
          onAction: (_) {},
        ),
        Pager(
          offset: offset,
          next: data.next,
          onPage: (value) => setState(() => offset = value),
        ),
      ],
    );
  }

  Widget _sale(RecordData sale) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          StatusBadge(sale.status),
          Text(
            '${shortDate(sale.s('business_date'))} · ${statusNames[sale.s('channel')] ?? sale.s('channel')}',
          ),
        ],
      ),
      const SizedBox(height: 16),
      for (final item in sale.rows('items'))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.s('name_snapshot'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                KeyValue(
                  'Jumlah',
                  quantity(item.number('quantity'), item.kind),
                ),
                KeyValue(
                  'Harga saat transaksi',
                  '${money(item.number('unit_price_rp'))} per ${item.kind == 'GRADE_A' ? 'kg' : 'unit'}',
                ),
                KeyValue('Nilai', money(item.number('gross_rp'))),
              ],
            ),
          ),
        ),
      for (final pair in const [
        ('gross_rp', 'Pendapatan kotor'),
        ('discount_rp', 'Diskon'),
        ('fee_rp', 'Biaya marketplace'),
        ('net_rp', 'Pendapatan bersih'),
        ('hpp_rp', 'HPP saat transaksi'),
      ])
        KeyValue(pair.$2, money(sale.number(pair.$1))),
      if (sale.s('void_reason').isNotEmpty)
        Notice('Alasan pembatalan: ${sale.s('void_reason')}'),
      const Text('Data historis disimpan sebagai catatan transaksi.'),
    ],
  );
}
