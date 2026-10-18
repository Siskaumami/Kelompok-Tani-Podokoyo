# Audit keamanan klien Flutter

Audit sumber dan pengujian lokal, 17 Oktober 2026. Scope hanya implementasi `apps/mobile`, kontrak server yang dibaca, platform manifests, dependensi dan asset. Bukan penetration test layanan production atau sertifikasi store.

## Permukaan serangan

URL build, response JSON/error yang tidak dipercaya, cookie sesi, CSRF, form multi-domain, token email, peralihan role, idempotency, unggahan galeri, redirect gambar, file PDF/share, native manifest dan cache. Server/database tetap menjadi otoritas tenant, role, stok, harga/HPP, audit, validation dan transaction lock.

## Temuan dan mitigasi di mobile

| Tingkat | Temuan yang ditinjau | Hasil |
| --- | --- | --- |
| CRITICAL | Penyimpanan password/credential, auth fork, bypass tenant | Tidak ada password/credential server yang dipersistenkan, JWT, tenant override, database langsung atau provider secret. |
| HIGH | Sesi bocor melalui redirect atau host lain | API tidak mengikuti redirect. Cookie hanya ke origin API. Pembacaan signed image dibatasi HTTPS Filebase dan client anonim tanpa Cookie/CSRF/Origin/Idempotency-Key; diuji dengan adapter terpisah. |
| HIGH | Transaksi rangkap setelah jawaban jaringan terputus | UUID v4 dari Random.secure, payload immutable dan key dipertahankan di memori; input terkunci pada hasil tidak pasti; hanya retry manual. Tidak ada background write/queue. Diuji pada form dan API. |
| HIGH | Password/sesi disimpan plaintext | Sesi opaque memakai flutter_secure_storage: Keychain `unlocked_this_device` dan Android secure storage default; CSRF hanya memori; password hanya input sementara. Backup/cloud/device transfer Android dinonaktifkan/dikecualikan. |
| HIGH | Hak Owner tersisa setelah perubahan akun | Server policy tidak diganti. UI Admin tidak membuat kontrol Owner; 401/ACCOUNT_CHANGED/CSRF_REJECTED menghapus state; `/auth/me` dimuat ulang setelah transfer dan saat resume. Diuji di provider dan navigasi. |
| MEDIUM | HTTP release atau TLS trust-all | Runtime configuration dan preflight Android/iOS mewajibkan HTTPS release; network security Android menolak cleartext release; ATS tetap default; tidak ada certificate callback/bypass. HTTP debug harus diisi eksplisit. |
| MEDIUM | Response/payload mutable, uang float, ID/path malformed | Model read-only rekursif; salinan edit independen; tipe angka/bool/string, UUID dan envelope diperiksa; BigInt untuk konversi/presentasi; path API dan filename PDF dibatasi. |
| MEDIUM | Query berulang ketika sesi dicabut saat refresh | Callback expiry idempotent, seluruh provider private memeriksa autentikasi, dan ganti password menghapus sesi sebelum invalidasi data. Regresi password-change dan expiry saat save lulus. |
| MEDIUM | Stale physical count menghasilkan koreksi salah | Tidak auto-refresh/retry count. STALE_BASELINE menampilkan aksi eksplisit, konfirmasi refresh dan instruksi hitung ulang. Reason null saat sesuai, wajib saat selisih, OTHER wajib keterangan; diuji tanpa write saat mengetik. |
| MEDIUM | Berkas berbahaya atau traversal | Header JPEG/PNG/WebP dan maksimum 5 MiB sebelum upload; server memvalidasi ulang/reencode. PDF base64 dibatasi, signature dan filename diperiksa; hanya cache aplikasi privat. Tidak mengeksekusi konten server. |
| LOW | Cache laporan/gambar bertahan lebih lama dari sesi | Cache data/gambar memori dihapus saat keluar. PDF privat dibersihkan saat sesi berakhir (best effort), dan ekspor lama >1 jam pada ekspor berikutnya. Tidak memakai public Downloads tanpa aksi pengguna. |
| INFORMATIONAL | Native push/OS association/account lifecycle | Kontrak backend yang belum tersedia didokumentasikan pada backend-constraints; tidak membuat success palsu atau izin native yang tidak dipakai. |

Tidak ditemukan masalah CRITICAL/HIGH terbuka yang dapat direproduksi pada kode mobile dalam scope review ini. Hasil ini tidak berarti tidak ada kerentanan lain.

## Detail kontrol

- Timeout HTTP 25 detik; JSON/error parsing terpusat mempertahankan kode/message/details/request ID. 403 biasa tetap permission error. Timeout/connection failure/malformed write tidak dilaporkan sebagai sukses.
- Tidak ada logger HTTP/body/credential, print sesi, cookie, password, CSRF atau signed URL. Diagnostik GoRouter dinonaktifkan; error UI tidak menampilkan stack trace Dart.
- Email token hanya memori; URL lengkap diverifikasi origin/path dan token 64 hex. Aktivasi sukses menyediakan jalur login baru; invalid/expired token mempertahankan pesan backend.
- Session material di secure storage dibatasi nama cookie yang dikenal, host, flags yang sesuai production dan lifetime server. Sesi tidak disimpan ke SharedPreferences secara langsung, file JSON, atau database aplikasi.
- Mutation payload tidak memuat org_id/role/authoritative balance/HPP/profit. Archive/void memakai endpoint khusus, bukan delete historis.
- File upload tetap lewat API. Hanya galeri yang dipanggil (`requestFullMetadata:false`); tidak ada kamera, lokasi, kontak, mikrofon atau broad-storage permission yang diminta kode mobile.
- Android launcher activity exported untuk launcher saja. Provider galeri/share dari dependency tidak exported. Tidak ada native background push service baru.
- iOS tidak memakai NSAllowsArbitraryLoads. Entitlement Keychain memakai application identifier; konfigurasi signing wajib diperiksa pada build Mac.
- Direct dependencies dipin dan lockfile disertakan. Manifest paket langsung/transitif ditinjau untuk kemampuan runtime. `flutter pub outdated` dijalankan; paket transitif yang lebih baru di luar constraint tidak dipaksa naik tanpa verifikasi SDK. Tidak ada SDK analytics/advertising dalam implementasi.

## Risiko tersisa yang membutuhkan lingkungan/penerbit/backend

| Tingkat | Bukti / batas | Tindak lanjut |
| --- | --- | --- |
| MEDIUM | Handler error existing `apps/server/src/app.ts` memanggil `console.error(error)` atas exception utuh. Potensi tercatatnya parameter driver tergantung bentuk exception; ini inferensi risiko dari pemanggilan tersebut. | Tinjau redaksi log pada deployment server sebelum distribusi. Tidak diubah karena write boundary. |
| MEDIUM | Tidak ada endpoint penghapusan akun/data; histori/audit sengaja dipertahankan. | Penerbit menetapkan proses permintaan, retensi dan deklarasi kebijakan yang sesuai. Menonaktifkan Admin bukan penghapusan data. |
| INFORMATIONAL | Tidak ada layanan staging, kredensial provider, akun store, signing key, atau domain final dalam input. | Uji login revocation lintas klien, TLS/rate limits, email/worker, upload dan PDF pada staging. |
| INFORMATIONAL | Linux tidak menyediakan Xcode/iOS SDK/perangkat Apple. | Jalankan build, Keychain/share/photo-picker, signing dan TestFlight pada macOS/iPhone. |
| LOW | Cache file yang sudah dibagikan ke aplikasi lain dikelola tujuan berbagi; crash dapat menunda cleanup cache privat. | Jelaskan perilaku ekspor dalam kebijakan privasi dan verifikasi file protection di perangkat release. |

Lihat validation.md untuk perintah, jumlah tes dan build yang benar-benar dieksekusi. Pemilihan foto dapat membuat salinan sementara di cache privat yang dikelola plugin/OS. Aplikasi tidak menyimpan draft transaksi ke disk; lifecycle cache native tetap diperiksa pada perangkat release.

Tidak ada secret production atau transaksi terhadap database production yang dipakai dalam verifikasi.
