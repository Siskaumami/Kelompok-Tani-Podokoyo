# Verifikasi UI terhadap web yang diberikan

Sumber visual: `apps/web/src/main.tsx`, `pages.tsx`, `ui.tsx`, dan keseluruhan aturan terkait di `styles.css`, termasuk override responsive terakhir. Token dicatat pada architecture-map.md. Widget memakai Inter (keluarga pertama CSS), white panels, background #f5faf6, brand asli dan ikon outline bawaan Flutter.

## Bukti

- Setiap 14 layar diuji pada viewport 320×740 dan 1024×768 tanpa exception layout.
- Golden native-rendered pada `test/goldens`: products-phone, opnames-phone, workspace-tablet dan login-phone, dengan font Inter/MaterialIcons dimuat pada tes.
- Golden ditinjau secara visual; hierarki, warna, label, tombol, panel Grade A, badge, serta drawer/sidebar dibandingkan kembali dengan sumber web.
- Teks tombol di golden diperbaiki agar memakai Inter yang dibundel, bukan font placeholder runner. Header dibuat dapat bertambah tinggi agar tidak meluap di ponsel kecil/ukuran teks besar.
- Tombol produk diuji posisi dua kolom: Edit/Riwayat, Harga / HPP/Nonaktifkan. Info `Sesuai` selesai opname diuji tidak berada dalam tombol.
- Auth invite-success → login baru, error/empty states, role Owner/Admin, input numeric/kg/password, conditional reason, stale refresh, upload retry dan mutation retry diuji pada widget.

## Adaptasi native yang mempertahankan semantik

| Area | Implementasi |
| --- | --- |
| Navigasi | Urutan 14 menu dan route sama; drawer di bawah 900, sidebar di tablet lebar; role dan Keluar selalu tersedia |
| Daftar | Kartu berlabel di ponsel; kartu berdampingan ketika lebar isi cukup, tanpa mengecilkan tabel |
| Tombol | Tombol utama hijau; secondary putih; row action putih dengan border/teks hijau dan radius sumber |
| Form | Dialog scroll dengan footer tetap terjangkau, keyboard sesuai tipe, date picker Indonesia, tanpa write saat mengetik |
| Cek stok | Reason dikosongkan/dinonaktifkan ketika sesuai; alasan wajib saat selisih; hasil selesai menjadi teks informasional |
| Grade A | Panel harga/HPP terpisah dari produk jadi; hanya Owner memiliki tombol perubahan |
| Status | Normal/warning/muted memakai warna dan label sumber; final/void/archive tidak memunculkan aksi yang tidak tersedia |
| Undangan native | Token fragment dipakai langsung; fallback tempel tautan lengkap bila asosiasi domain belum disiapkan; sukses menuju login baru |
| PDF/website | Native share untuk file server dan browser eksternal untuk website; tidak memakai WebView |

Golden adalah fixture yang sengaja terisolasi dari data nyata. Ini bukan bukti pengujian pada hardware Android/iPhone. Pemeriksaan perangkat nyata, native picker/share dan iOS archive tetap tercatat terpisah pada validation.md.
