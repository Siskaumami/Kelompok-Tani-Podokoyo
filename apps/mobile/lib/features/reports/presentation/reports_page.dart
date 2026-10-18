import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/feature_provider.dart';
import '../../../core/data/feature_spec.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/detail_dialog.dart';
import '../../../core/widgets/record_list.dart';
import '../data/report_data.dart';
import '../data/report_export.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(objectProvider('/notifications'))
      .when(
        loading: () => const Loading(),
        error: (e, s) => ErrorNotice(
          e,
          retry: () => ref.invalidate(objectProvider('/notifications')),
        ),
        data: (data) => ReportPeriodView(
          key: ValueKey(data.s('business_date')),
          today: data.s('business_date'),
        ),
      );
}

class ReportPeriodView extends ConsumerStatefulWidget {
  const ReportPeriodView({super.key, required this.today});
  final String today;
  @override
  ConsumerState<ReportPeriodView> createState() => _ReportPeriodViewState();
}

class _ReportPeriodViewState extends ConsumerState<ReportPeriodView> {
  late String _from;
  late String _to;
  String _preset = 'today';
  bool _exporting = false;
  AppError? _exportError;
  final _exportKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    _from = widget.today;
    _to = widget.today;
  }

  void _range(String range) {
    final today = DateTime.parse(widget.today);
    setState(() {
      _preset = range;
      _from = switch (range) {
        'month' => isoDate(DateTime(today.year, today.month)),
        'year' => isoDate(DateTime(today.year)),
        _ => widget.today,
      };
      _to = switch (range) {
        'month' => isoDate(DateTime(today.year, today.month + 1, 0)),
        'year' => isoDate(DateTime(today.year, 12, 31)),
        _ => widget.today,
      };
    });
  }

  Future<void> _date(bool from) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(from ? _from : _to),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (date != null && mounted) {
      setState(() {
        _preset = 'custom';
        if (from) {
          _from = isoDate(date);
        } else {
          _to = isoDate(date);
        }
      });
    }
  }

  Future<void> _pdf() async {
    final from = _from, to = _to;
    final box = _exportKey.currentContext?.findRenderObject() as RenderBox?;
    final position = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    try {
      await ref.read(reportExportProvider).share(from, to, position);
    } catch (error) {
      if (mounted) setState(() => _exportError = AppError.from(error));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (_from, _to);
    final report = ref.watch(reportProvider(key));
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            'Pembukuan & laporan',
            action: ElevatedButton.icon(
              key: _exportKey,
              onPressed: _exporting || !report.hasValue ? null : _pdf,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(_exporting ? 'Menyiapkan…' : 'Unduh PDF'),
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final choice in const [
                      ('today', 'Hari ini'),
                      ('month', 'Bulan ini'),
                      ('year', 'Tahun ini'),
                    ])
                      ChoiceChip(
                        label: Text(choice.$2),
                        selected: _preset == choice.$1,
                        onSelected: (_) => _range(choice.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _date(true),
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text('Dari ${shortDate(_from)}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _date(false),
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text('Sampai ${shortDate(_to)}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_exportError != null) ErrorNotice(_exportError!),
          report.when(
            loading: () => const Loading(),
            error: (error, stack) => ErrorNotice(
              error,
              retry: () => ref.invalidate(reportProvider(key)),
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Panel(
                  child: Column(
                    children: [
                      for (final entry in reportLabels.entries)
                        Container(
                          color: ['net_rp', 'profit_rp'].contains(entry.key)
                              ? const Color(0xffe4f5e9)
                              : null,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Text(entry.value)),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  money(data.totals.number(entry.key)),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Transaksi pendukung',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${data.totals.number('sale_count')} aktif · ${data.totals.number('voided_count')} dibatalkan',
                ),
                const SizedBox(height: 16),
                RecordList(
                  rows: data.transactions,
                  empty: 'Tidak ada penjualan dalam periode ini',
                  cells: (r) => [
                    CellData(
                      'Tanggal / kanal',
                      shortDate(r.s('business_date')),
                      secondary: [
                        statusNames[r.s('channel')] ?? r.s('channel'),
                      ],
                    ),
                    CellData('Status', '', badge: r.status),
                    CellData('Bersih', money(r.number('net_rp'))),
                    CellData('HPP', money(r.number('hpp_rp'))),
                  ],
                  actions: (r) => [
                    RecordAction.detail('Rincian', DetailSpec('sale', r)),
                  ],
                  onAction: (action) =>
                      showRecordDetail(context, action.detail!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
