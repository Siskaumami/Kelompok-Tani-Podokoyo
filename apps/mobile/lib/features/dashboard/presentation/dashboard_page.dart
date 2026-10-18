import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/feature_provider.dart';
import '../../../core/data/feature_spec.dart';
import '../../../core/network/json_data.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/record_list.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        ref.invalidate(objectProvider('/overview'));
        ref.invalidate(objectProvider('/notifications'));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(objectProvider('/overview'))
      .when(
        loading: () => const Loading(),
        error: (error, stack) => SingleChildScrollView(
          child: ErrorNotice(
            error,
            retry: () => ref.invalidate(objectProvider('/overview')),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(objectProvider('/overview'));
            ref.invalidate(objectProvider('/notifications'));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: _body(data),
          ),
        ),
      );
  Widget _body(RecordData data) {
    final counts = data.object('counts');
    final inventory = data.rows('inventory');
    final sales = data.object('today_sales');
    final started =
        BigInt.parse(counts.number('harvest_count')) > BigInt.zero ||
        BigInt.parse(counts.number('sale_count')) > BigInt.zero ||
        inventory.any((r) => BigInt.parse(r.number('balance')) > BigInt.zero);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          data.s('organization_name'),
          eyebrow: 'SELAMAT DATANG DI RUANG KERJA',
          action: ElevatedButton.icon(
            onPressed: () => context.go('/dashboard/harvests'),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Catat panen'),
          ),
        ),
        ref
            .watch(objectProvider('/notifications'))
            .when(
              data: (n) => n.flag('reminder_due')
                  ? Notice(
                      'Pencatatan penjualan hari ini belum dikonfirmasi. Catat transaksi yang terjadi, atau konfirmasikan tidak ada penjualan.',
                      action: TextButton(
                        onPressed: () => context.go('/dashboard/sales'),
                        child: const Text('Periksa penjualan →'),
                      ),
                    )
                  : const SizedBox(),
              error: (e, s) => ErrorNotice(
                e,
                retry: () => ref.invalidate(objectProvider('/notifications')),
              ),
              loading: () => const SizedBox(),
            ),
        if (BigInt.parse(counts.number('plans_needing_review')) > BigInt.zero)
          Notice(
            '${count(counts.number('plans_needing_review'))} rencana perlu disesuaikan dengan stok fisik terbaru.',
            action: TextButton(
              onPressed: () => context.go('/dashboard/plans'),
              child: const Text('Tinjau rencana'),
            ),
          ),
        if (!started)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MULAI DARI CATATAN PERTAMA',
                  style: TextStyle(fontSize: 9),
                ),
                const SizedBox(height: 16),
                Text(
                  'Setiap hasil panen\npunya perjalanan.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Catat panen dan hasil sortir. Setelah difinalisasi, Grade A dan Grade B otomatis masuk ke persediaan yang sesuai.',
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/dashboard/harvests'),
                  child: const Text('Catat panen pertama →'),
                ),
                const SizedBox(height: 24),
                for (final pair in const [
                  ('Panen & sortir', 'Catat hasil yang benar-benar diterima.'),
                  ('Stok & produksi', 'Jaga catatan sesuai kondisi fisik.'),
                  (
                    'Penjualan & laporan',
                    'Ekonomi transaksi tersimpan di riwayat.',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: KeyValue(pair.$1, pair.$2),
                  ),
              ],
            ),
          )
        else ...[
          LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth > 700
                  ? (c.maxWidth - 24) / 3
                  : c.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: StatCard(
                      label: 'Penjualan hari ini',
                      value: money(sales.number('net_rp')),
                      note:
                          '${count(sales.number('sale_count'))} transaksi aktif',
                    ),
                  ),
                  for (final row in inventory.where(
                    (i) => i.kind != 'FINISHED',
                  ))
                    SizedBox(
                      width: width,
                      child: StatCard(
                        label: row.s('name'),
                        value: quantity(row.number('balance'), row.kind),
                        note: row.kind == 'GRADE_B'
                            ? '${quantity(row.number('planned_g'), row.kind)} dialokasikan'
                            : 'Siap untuk penjualan bahan baku',
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                SectionTitle(
                  'Persediaan saat ini',
                  action: TextButton(
                    onPressed: () => context.go('/dashboard/inventory'),
                    child: const Text('Semua pergerakan →'),
                  ),
                ),
                const SizedBox(height: 14),
                RecordList(
                  rows: inventory,
                  cells: (row) => [
                    CellData('Barang', row.s('name')),
                    CellData(
                      'Stok tercatat',
                      quantity(row.number('balance'), row.kind),
                    ),
                    CellData(
                      'Jenis',
                      row.kind == 'FINISHED' ? 'Produk jadi' : 'Bahan baku',
                    ),
                  ],
                  actions: (_) => const [],
                  onAction: (_) {},
                  empty: 'Belum ada barang',
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth > 700
                ? (c.maxWidth - 24) / 3
                : c.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in const [
                  (
                    'products',
                    Icons.inventory_2_outlined,
                    'Kelola produk',
                    'Isi katalog, harga dan biaya per unit.',
                  ),
                  (
                    'production',
                    Icons.factory_outlined,
                    'Catat hasil produksi',
                    'Pemakaian nyata dan hasil jadi.',
                  ),
                  (
                    'content',
                    Icons.eco_outlined,
                    'Lengkapi website',
                    'Terbitkan profil desa dan anggota.',
                  ),
                ])
                  SizedBox(
                    width: width,
                    child: QuickLinkCard(
                      icon: item.$2,
                      title: item.$3,
                      body: item.$4,
                      onTap: () => context.go('/dashboard/${item.$1}'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
