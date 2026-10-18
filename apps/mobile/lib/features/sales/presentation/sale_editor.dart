import '../data/sale_draft.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/data/feature_spec.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/forms/form_spec.dart';
import '../../../core/widgets/forms/mutation_dialog.dart';

Future<void> showSaleEditor(
  BuildContext context,
  WidgetRef ref,
  FeatureBundle data,
) async {
  final outcome = await showDialog<FormOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SaleEditor(data: data),
  );
  ref.read(dataEpochProvider.notifier).advance();
  if (outcome == FormOutcome.saved && context.mounted) {
    showSuccess(context, 'Penjualan berhasil dicatat.');
  }
}

class SaleEditor extends StatefulWidget {
  const SaleEditor({super.key, required this.data});
  final FeatureBundle data;
  @override
  State<SaleEditor> createState() => _SaleEditorState();
}

class _SaleEditorState extends State<SaleEditor> {
  final _lines = [SaleDraftLine()];
  @override
  Widget build(BuildContext context) {
    final inventory = widget.data.rows('inventory');
    final products = widget.data.rows('products');
    return MutationDialog(
      spec: FormSpec(
        title: 'Catat penjualan',
        path: '/sales',
        description: 'Masukkan transaksi yang benar-benar terjadi. Harga kosong memakai harga saat pencatatan; isi harga aktual untuk transaksi dengan harga berbeda.',
        initial: {'business_date': widget.data.today, 'channel': 'OFFLINE'},
        fields: [
          const FieldSpec(
            'business_date',
            'Tanggal transaksi',
            kind: InputKind.date,
          ),
          FieldSpec(
            'channel',
            'Tempat penjualan',
            kind: InputKind.select,
            choices: [
              'OFFLINE',
              'WHATSAPP',
              'SHOPEE',
              'TOKOPEDIA',
            ].map((v) => Choice(v, statusNames[v]!)).toList(),
          ),
          const FieldSpec('external_ref', 'Nomor pesanan', optional: true),
          const FieldSpec(
            'discount_rp',
            'Total diskon',
            kind: InputKind.integer,
            optional: true,
            unit: 'Rp',
          ),
          const FieldSpec(
            'fee_rp',
            'Biaya marketplace',
            kind: InputKind.integer,
            optional: true,
            unit: 'Rp',
          ),
          const FieldSpec(
            'notes',
            'Catatan',
            kind: InputKind.textarea,
            optional: true,
            maxLength: 2000,
          ),
        ],
        prepare: (v) {
          if (_lines.isEmpty || _lines.length > 50) {
            throw const FormatException('Pilih 1 sampai 50 barang.');
          }
          return {
            ...v,
            'items': _lines
                .map((line) => saleLinePayload(line, inventory))
                .toList(),
          };
        },
      ),
      extra: (locked, changed) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Barang yang terjual',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < _lines.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Panel(
                key: _lines[index].key,
                padding: const EdgeInsets.all(12),
                child: Builder(
                  builder: (context) {
                    final line = _lines[index];
                    final item = inventory
                        .where((i) => i.id == line.itemId)
                        .firstOrNull;
                    final product = products
                        .where((p) => p.s('item_id') == line.itemId)
                        .firstOrNull;
                    final price = item?.kind == 'GRADE_A'
                        ? widget.data.organization.number('grade_a_price_rp')
                        : product?.number('price_rp');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Barang ${index + 1}'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: item?.id,
                          isExpanded: true,
                          items: inventory
                              .where((i) => i.kind != 'GRADE_B')
                              .map(
                                (i) => DropdownMenuItem(
                                  value: i.id,
                                  child: Text(
                                    i.s('name'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: locked
                              ? null
                              : (value) {
                                  changed();
                                  setState(() {
                                    line.itemId = value ?? '';
                                    line.quantity = '';
                                    line.price = '';
                                  });
                                },
                          validator: (value) =>
                              value == null ? 'Pilih barang.' : null,
                          decoration: const InputDecoration(
                            hintText: 'Pilih barang…',
                          ),
                        ),
                        if (item != null)
                          Text(
                            'Tersedia ${quantity(item.number('balance'), item.kind)}',
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey('${line.key}:${line.itemId}:quantity'),
                          initialValue: line.quantity,
                          enabled: !locked,
                          decoration: InputDecoration(
                            labelText:
                                'Jumlah (${item?.kind == 'GRADE_A' ? 'kg' : 'unit'})',
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: item?.kind == 'GRADE_A',
                          ),
                          onChanged: (value) {
                            line.quantity = value;
                            changed();
                          },
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Isi jumlah.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey('${line.key}:${line.itemId}:price'),
                          initialValue: line.price,
                          enabled: !locked,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                'Harga ${item?.kind == 'GRADE_A' ? 'per kg' : 'per unit'} (Rp)',
                          ),
                          onChanged: (value) {
                            line.price = value;
                            changed();
                          },
                        ),
                        if (price != null) Text('Saat ini ${money(price)}'),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Hapus barang dari transaksi',
                            onPressed: locked || _lines.length == 1
                                ? null
                                : () {
                                    changed();
                                    setState(() => _lines.removeAt(index));
                                  },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: locked || _lines.length >= 50
                ? null
                : () {
                    changed();
                    setState(() => _lines.add(SaleDraftLine()));
                  },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah barang'),
          ),
        ],
      ),
    );
  }
}
