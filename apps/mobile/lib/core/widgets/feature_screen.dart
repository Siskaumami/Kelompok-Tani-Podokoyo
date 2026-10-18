import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/products/data/product_feature.dart';
import '../../features/registry.dart';
import '../../features/sales/presentation/sale_editor.dart';
import '../../features/sales/widgets/confirmation_panel.dart';
import '../auth/auth_controller.dart';
import '../data/feature_provider.dart';
import '../data/feature_spec.dart';
import '../utils/format.dart';
import 'common.dart';
import 'detail_dialog.dart';
import 'forms/mutation_dialog.dart';
import 'record_list.dart';

class FeatureScreen extends ConsumerStatefulWidget {
  const FeatureScreen(this.id, {super.key});
  final String id;
  @override
  ConsumerState<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends ConsumerState<FeatureScreen>
    with WidgetsBindingObserver {
  int offset = 0;
  String filter = 'ALL';
  Timer? _timer;
  final _scroll = ScrollController();
  FeatureSpec get feature => features[widget.id]!;
  (String, int) get query => (widget.id, offset);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    final seconds =
        feature.refreshSeconds ?? (widget.id == 'sales' ? 60 : null);
    if (seconds != null) {
      _timer = Timer.periodic(Duration(seconds: seconds), (_) {
        if (mounted) ref.invalidate(featureProvider(query));
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      ref.invalidate(featureProvider(query));
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _action(RecordAction action) async {
    if (action.form != null) {
      await showMutationForm(context, ref, action.form!);
    } else if (action.detail != null) {
      await showRecordDetail(context, action.detail!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final state = ref.watch(featureProvider(query));
    final data = state.asData?.value;
    final canCreate =
        feature.createLabel != null &&
        (!feature.ownerCreate || (user?.isOwner ?? false));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(featureProvider(query));
      },
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(
              feature.title,
              action: canCreate
                  ? ElevatedButton.icon(
                      onPressed: data == null
                          ? null
                          : () async {
                              if (widget.id == 'sales') {
                                await showSaleEditor(context, ref, data);
                              } else if (feature.create != null) {
                                await showMutationForm(
                                  context,
                                  ref,
                                  feature.create!(data),
                                );
                              }
                            },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(feature.createLabel!),
                    )
                  : null,
            ),
            if (feature.notice != null) Notice(feature.notice!),
            state.when(
              loading: () => const Loading(),
              error: (error, stack) => ErrorNotice(
                error,
                retry: () => ref.invalidate(featureProvider(query)),
              ),
              data: (data) {
                final rows = widget.id == 'inventory' && filter != 'ALL'
                    ? data.page.items
                          .where(
                            (r) => filter == 'RAW'
                                ? r.kind != 'FINISHED'
                                : r.kind == 'FINISHED',
                          )
                          .toList()
                    : data.page.items;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.id == 'products') _gradeA(data),
                    if (['plans', 'production'].contains(widget.id) &&
                        data.activeProducts().isEmpty)
                      const Notice(
                        'Tambahkan produk sebelum merencanakan atau mencatat produksi.',
                      ),
                    if (widget.id == 'sales' && data.notifications != null)
                      SalesConfirmationPanel(data.notifications!),
                    if (widget.id == 'inventory')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 8,
                          children: [
                            for (final pair in const [
                              ('ALL', 'Semua persediaan'),
                              ('RAW', 'Bahan baku'),
                              ('FINISHED', 'Produk jadi'),
                            ])
                              ChoiceChip(
                                label: Text(pair.$2),
                                selected: filter == pair.$1,
                                onSelected: (_) =>
                                    setState(() => filter = pair.$1),
                              ),
                          ],
                        ),
                      ),
                    Panel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          RecordList(
                            rows: rows,
                            cells: feature.cells,
                            actions: (r) => user == null
                                ? []
                                : feature.actions(r, data, user),
                            onAction: (action) => unawaited(_action(action)),
                            empty: 'Belum ada ${feature.title.toLowerCase()}',
                          ),
                          if (feature.paged)
                            Pager(
                              offset: offset,
                              next: data.page.nextOffset,
                              onPage: (value) {
                                setState(() => offset = value);
                                if (_scroll.hasClients) _scroll.jumpTo(0);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradeA(FeatureBundle data) {
    final phone = MediaQuery.sizeOf(context).width <= 640;
    final values = [
      (
        'Harga jual / kg',
        money(data.organization.number('grade_a_price_rp')),
      ),
      ('HPP / kg', money(data.organization.number('grade_a_hpp_rp'))),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Panel(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BAHAN BAKU',
              style: TextStyle(fontSize: 9, color: Color(0xff748c7c)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Harga & HPP Grade A',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            const Text('Nilai per kilogram untuk penjualan kentang Grade A.'),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final stacked =
                    phone ||
                    c.maxWidth < 270 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 1.4;
                final cards = [
                  for (final value in values)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xfff8fbf9),
                        border: Border.all(color: const Color(0xffdfeae2)),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value.$1,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xff748c7c),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            value.$2,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ];
                if (stacked) {
                  return Column(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        SizedBox(width: double.infinity, child: cards[i]),
                        if (i + 1 < cards.length) const SizedBox(height: 12),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                );
              },
            ),
            if (ref.watch(authProvider).user?.isOwner ?? false) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: phone ? double.infinity : null,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 39),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                  ),
                  onPressed: () => showMutationForm(
                    context,
                    ref,
                    gradeAForm(data.organization),
                  ),
                  child: const Text('Ubah harga / HPP'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
