# Pemeriksaan monorepo lama

Dijalankan pada salinan byte-identik sumber lama di direktori validasi terisolasi, supaya npm tidak menulis node_modules/dist di luar apps/mobile pada repository kerja. Salinan/hasil build sementara tidak disertakan dalam paket.

| Perintah | Hasil |
| --- | --- |
| npm ci --no-audit --no-fund | Sukses; instalasi hanya pada salinan validasi |
| npm run typecheck | Lulus |
| npm run lint | Gagal: 3 error bawaan sumber ZIP |
| npm run test | 32 lulus, 2 dilewati (PostgreSQL integration tanpa database disposable) |
| npm run build | Lulus |

Error lint yang terkonfirmasi:

- apps/server/src/modules/reports/service.ts: import Row tidak dipakai (baris 6).
- apps/web/src/main.tsx: import day tidak dipakai (baris 8).
- apps/web/src/pages.tsx: catch block kosong pada parsing WhatsApp (baris 16).

Ketiganya sudah ada pada file asli sebelum penambahan Flutter. Tidak diperbaiki karena instruksi eksplisit melarang perubahan file lama di luar apps/mobile. Ini bukan error analisis Dart. Checksum file asli tetap sama; verifikasi dengan python tool/verify_original_files.py dari apps/mobile.
