# Peta arsitektur dan dampak perubahan

Diperiksa dari sumber ZIP yang diberikan, 17 Oktober 2026. Semua implementasi baru berada di `apps/mobile`; server, web, database, shared schemas, konfigurasi root, dan dokumentasi lama tetap read-only.

## Bukti dan keputusan

| Area | Sumber otoritatif | Adaptasi native |
| --- | --- | --- |
| HTTP | `apps/server/src/app.ts`, `apps/web/src/api.ts` | `/api/v1`, envelope `data`, strict input, batas waktu 25 detik |
| Sesi | `modules/auth/service.ts` | cookie opaque 12 jam, idle 2 jam, cookie hanya host API, Keychain/Android secure storage; CSRF hanya memori |
| Origin | `core/config.ts`, `originGuard` | header Origin persis APP_URL; `APP_ORIGIN` terpisah bila origin API berbeda |
| Mutasi | `core/transactions.ts` | UUID v4, tidak retry otomatis, payload dan key dibekukan setelah respons tidak pasti |
| Hak akses | `authorize`, users service | OWNER mengundang/mengatur Admin, memindahkan Owner, mengubah settings; ADMIN operasional; SUPER_ADMIN tidak masuk workspace |
| Angka | `packages/shared/src/schemas.ts`, ADR 004 | transport string desimal; kg ke gram dengan BigInt tanpa float; uang Rupiah bulat |
| Stok | inventory service, migrations | hanya baca balance/revision; perubahan lewat endpoint domain |
| Panen | harvest service | draf boleh parsial; finalisasi terpisah; pembatalan dengan alasan |
| Produksi | production service | rencana bukan konsumsi; hasil aktual dan selisih dari server; rencana NEEDS_REVIEW terlihat |
| Produk | products service | metadata dan versi ekonomi terpisah; HPP dari server; Grade A dalam panel terpisah |
| Cek stok | stock-opname service, migration 0003 | alasan null jika cocok; alasan wajib jika berbeda; OTHER wajib keterangan; STALE_BASELINE meminta refresh dan hitung ulang eksplisit |
| Penjualan | sales service | Grade A dan FINISHED; 1–50 baris; harga kosong dihilangkan; diskon/fee; detail snapshot; void; konfirmasi harian bukan tutup buku |
| Laporan | reports service | angka dan PDF berasal server; tidak menghitung ulang laporan di Dart |
| Gambar | files service | satu multipart `image`, JPEG/PNG/WebP, maksimum 5 MiB; redirect signed HTTPS diambil tanpa cookie/CSRF |
| Pengingat | notifications service | state in-app dan konfirmasi harian; tidak mengirim subscription native palsu ke Web Push |
| Publik | public-content service | DTO publik saja; tidak merender data ERP ke katalog publik |
| Tampilan | `pages.tsx`, `ui.tsx`, `main.tsx`, `styles.css` | urutan menu/label/status sama; kartu pada ponsel, panel berdampingan di tablet, drawer di bawah breakpoint 900 |

## Token desain dari CSS

Accent `#148339`; ink `#173b27`; muted `#607366`; pale `#e8fff0`; border `#dbeade`; panel border `#dfeae2`; white `#ffffff`. Panel radius 13/11, tombol utama 10, row-action 8. Row-action putih dengan border `#bdd8c4`, teks `#19743a`. Badge normal `#e8f5eb/#1e6736/#d9ecde`; warning `#f0f7dc/#52622d/#dce6c5`; muted `#f2f5f2/#657569/#e1e9e3`. Field border `#d8e5dc`; error `#fff6f3/#803f2b/#ebd7cf`. Keluarga CSS Inter/system sans; tidak mengambil font dari jaringan.

## Batas perubahan dan dampak

Satu klien REST baru. Tidak ada perubahan kontrak API, database, migration, ledger, HPP, pricing history, calculation laporan, audit, policy, public DTO, PWA, atau klien web. Pengujian klien memakai transport palsu yang terisolasi; tidak menyentuh database produksi. Mutasi tidak disimpan sebagai antrean offline. Cache bacaan hanya memori selama sesi, dihapus saat keluar dan divalidasi ulang saat resume. Pemilik lama mengambil ulang `/auth/me` setelah transfer, sehingga aksi Owner segera hilang. Sesi pemilik baru yang dicabut server diperlakukan sebagai sesi kedaluwarsa.
