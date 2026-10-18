import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/json_data.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/forms/mutation_dialog.dart';
import '../data/sales_feature.dart';

class SalesConfirmationPanel extends ConsumerWidget {
  const SalesConfirmationPanel(this.data, {super.key});
  final RecordData data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shortDate(data.s('business_date')),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            data['confirmation'] != null
                ? 'Pencatatan hari ini sudah dikonfirmasi.'
                : 'Sudah selesai mencatat penjualan hari ini?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Konfirmasi membantu pengingat harian. Transaksi tambahan tetap boleh dicatat.',
          ),
          const SizedBox(height: 12),
          if (data['confirmation'] != null)
            StatusBadge(data.object('confirmation').s('status'))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RowAction(
                  'Selesai mencatat',
                  onPressed: () => showMutationForm(
                    context,
                    ref,
                    salesConfirmation(data, 'COMPLETED'),
                  ),
                ),
                RowAction(
                  'Tidak ada penjualan',
                  onPressed: () => showMutationForm(
                    context,
                    ref,
                    salesConfirmation(data, 'NO_SALES'),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
