import 'package:flutter/material.dart';

import '../data/feature_spec.dart';
import '../network/json_data.dart';
import '../theme/tokens.dart';
import 'common.dart';

class RecordList extends StatelessWidget {
  const RecordList({
    super.key,
    required this.rows,
    required this.cells,
    required this.actions,
    required this.onAction,
    this.empty = 'Belum ada catatan',
  });
  final List<RecordData> rows;
  final List<CellData> Function(RecordData) cells;
  final List<RecordAction> Function(RecordData) actions;
  final ValueChanged<RecordAction> onAction;
  final String empty;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Empty(
        empty,
        description:
            'Catatan nyata akan tampil di sini setelah Anda menyimpannya.',
      );
    }
    final phone = MediaQuery.sizeOf(context).width <= 640;
    if (phone) {
      return Container(
        width: double.infinity,
        color: const Color(0xfff6faf7),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i + 1 < rows.length ? 12 : 0,
                ),
                child: RecordTile(
                  key: ValueKey(rows[i].id),
                  cells: cells(rows[i]),
                  actions: actions(rows[i]),
                  onAction: onAction,
                ),
              ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 700 ? 2 : 1;
        final width = (c.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final row in rows)
              SizedBox(
                width: width,
                child: RecordTile(
                  key: ValueKey(row.id),
                  cells: cells(row),
                  actions: actions(row),
                  onAction: onAction,
                ),
              ),
          ],
        );
      },
    );
  }
}

class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.cells,
    required this.actions,
    required this.onAction,
  });
  final List<CellData> cells;
  final List<RecordAction> actions;
  final ValueChanged<RecordAction> onAction;
  @override
  Widget build(BuildContext context) => Panel(
    radius: 10,
    child: LayoutBuilder(
      builder: (context, c) {
        final phone = MediaQuery.sizeOf(context).width <= 640;
        final two =
            c.maxWidth >= 280 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.6;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                for (var i = 0; i < cells.length; i++)
                  SizedBox(
                    width:
                        (phone && i == 0) ||
                            cells[i].informational ||
                            cells[i].label == 'Profil' ||
                            !two
                        ? c.maxWidth
                        : (c.maxWidth - 18) / 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cells[i].label,
                          style: const TextStyle(
                            color: Color(0xff899c8e),
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (cells[i].badge != null)
                          StatusBadge(cells[i].badge!)
                        else
                          Text(
                            cells[i].primary,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cells[i].informational
                                  ? Tokens.rowText
                                  : Tokens.ink,
                            ),
                          ),
                        for (final text in cells[i].secondary)
                          Text(
                            text,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xff839488),
                              height: 1.7,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (actions.length > 1 &&
                  MediaQuery.textScalerOf(context).scale(1) < 1.4)
                Column(
                  children: [
                    for (var i = 0; i < actions.length; i += 2)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i + 2 < actions.length ? 8 : 0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: RowAction(
                                actions[i].label,
                                onPressed: () => onAction(actions[i]),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: i + 1 < actions.length
                                  ? RowAction(
                                      actions[i + 1].label,
                                      onPressed: () => onAction(actions[i + 1]),
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in actions)
                      RowAction(
                        action.label,
                        onPressed: () => onAction(action),
                      ),
                  ],
                ),
            ],
          ],
        );
      },
    ),
  );
}

class Pager extends StatelessWidget {
  const Pager({
    super.key,
    required this.offset,
    required this.next,
    required this.onPage,
  });
  final int offset;
  final int? next;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) {
    if (offset == 0 && next == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton(
            onPressed: offset > 0 ? () => onPage(offset - 30) : null,
            child: const Text('Sebelumnya'),
          ),
          Text('Halaman ${offset ~/ 30 + 1}'),
          OutlinedButton(
            onPressed: next == null ? null : () => onPage(next!),
            child: const Text('Berikutnya'),
          ),
        ],
      ),
    );
  }
}
