import 'package:flutter/material.dart';

class WorkspaceDestination {
  const WorkspaceDestination(this.segment, this.label, this.icon);
  final String segment;
  final String label;
  final IconData icon;
  String get path => '/dashboard${segment.isEmpty ? '' : '/$segment'}';
}

const destinations = [
  WorkspaceDestination('', 'Ringkasan', Icons.dashboard_outlined),
  WorkspaceDestination('harvests', 'Panen', Icons.grass_outlined),
  WorkspaceDestination('inventory', 'Persediaan', Icons.warehouse_outlined),
  WorkspaceDestination('products', 'Produk & HPP', Icons.inventory_2_outlined),
  WorkspaceDestination(
    'plans',
    'Rencana produksi',
    Icons.account_tree_outlined,
  ),
  WorkspaceDestination('production', 'Hasil produksi', Icons.factory_outlined),
  WorkspaceDestination('opnames', 'Cek stok fisik', Icons.fact_check_outlined),
  WorkspaceDestination('sales', 'Penjualan', Icons.shopping_bag_outlined),
  WorkspaceDestination('reports', 'Pembukuan', Icons.bar_chart_outlined),
  WorkspaceDestination('content', 'Konten website', Icons.web_outlined),
  WorkspaceDestination('users', 'Pengguna', Icons.people_outline),
  WorkspaceDestination('farmers', 'Anggota tani', Icons.groups_outlined),
  WorkspaceDestination(
    'audit',
    'Riwayat aktivitas',
    Icons.receipt_long_outlined,
  ),
  WorkspaceDestination('settings', 'Pengaturan', Icons.settings_outlined),
];
