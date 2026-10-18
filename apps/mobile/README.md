Kelompok Tani Podokoyo — Flutter mobile
Klien native Android/iOS untuk ERP yang sudah ada. Jalankan perintah dari `apps/mobile`. Seluruh file monorepo lama tetap utuh; tidak perlu mendaftarkan Flutter di workspace npm.
Mulai bekerja
Diuji dengan Flutter 3.47.7, Dart 3.13.5. Android memakai konfigurasi toolchain Flutter: minimum SDK 24, target/compile SDK 36, Java JDK 17 lengkap dengan `javac`, Gradle 9.3.1, AGP 9.1.0, NDK 28.2.13676358. Dependensi JNI juga membutuhkan platform SDK 35 pada mesin build. iOS project menargetkan iOS 15.0; build memerlukan macOS/Xcode dan konfigurasi signing penerbit.
```sh
flutter doctor -v
flutter pub get
flutter devices
flutter run -d <device-id> --dart-define=API_BASE_URL=https://erp.example.com
```
Alamat contoh bukan layanan aktif proyek. Isi alamat deployment sendiri. `API_BASE_URL` menerima origin atau akhiran `/api/v1`, tanpa kredensial, query, fragment, atau path lain. Tidak ada nilai default yang diam-diam menunjuk layanan tertentu.
Server memeriksa `Origin` terhadap `APP_URL` backend, termasuk saat login. Jika origin website dan API berbeda:
```sh
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=APP_ORIGIN=https://web.example.com
```
`APP_ORIGIN` harus persis origin `APP_URL` server. Jika tidak diberikan, origin API dipakai. Jangan mengirim API key, password atau kredensial server melalui dart-define; nilai build dapat dibaca dari aplikasi.
Android debug dapat memakai URL HTTP development yang diberikan secara eksplisit. Android release menolak cleartext melalui network security config dan pemeriksaan URL. iOS mempertahankan ATS default: gunakan HTTPS yang sertifikatnya dipercaya perangkat. Tidak ada bypass TLS atau pengecualian ATS global.
Untuk CI terisolasi, `CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true` menonaktifkan telemetri toolchain dan mencegah deteksi otomatis metadata cloud oleh Flutter. Ini bukan pengaturan koneksi aplikasi.

Android Emulator lokal
Untuk backend lokal pada host Windows dengan API port `3000` dan web origin `http://localhost:5173`, Android Emulator mengakses host melalui `10.0.2.2`:
```powershell
flutter run --profile -d <emulator-id> `
  --dart-define=API_BASE_URL=http://10.0.2.2:3000 `
  --dart-define=APP_ORIGIN=http://localhost:5173
```
`localhost` di dalam emulator menunjuk emulator itu sendiri, bukan Windows host. `APP_ORIGIN` harus tetap mengikuti origin yang diterima backend; jangan mengubahnya hanya untuk membuat tombol website development terbuka. Profile mode telah dijalankan secara lokal pada emulator Android 16 untuk smoke-check UI/login/ERP, tetapi ini bukan pengganti pengujian perangkat fisik lintas kelas hardware.
Modul
Urutan menu sama dengan web: Ringkasan, Panen, Persediaan, Produk & HPP, Rencana produksi, Hasil produksi, Cek stok fisik, Penjualan, Pembukuan, Konten website, Pengguna, Anggota tani, Riwayat aktivitas, Pengaturan.
Aksi meliputi draf/finalisasi/pembatalan panen; riwayat stok; metadata, publikasi, versi harga/HPP dan penonaktifan produk; panel Grade A tersendiri; rencana dan hasil produksi nyata; pemeriksaan stok dengan alasan kondisional dan hitung ulang eksplisit; transaksi multi-barang, harga aktual, diskon, fee, pembatalan dan konfirmasi harian; laporan periode/PDF; konten/foto; undangan Admin, status akses dan transfer Owner; publikasi/arsip petani; before/after audit; organisasi, pengingat, dan ganti password.
Website publik tetap dibuka melalui browser eksternal dari `Lihat website`. Tidak ada WebView, checkout baru, atau salinan backend di Flutter.
Arsitektur
```text
lib/app/                 bootstrap, providers, router, shell dan urutan menu
lib/core/auth/           sesi dan role live dari server
lib/core/network/        Dio, response parser, idempotensi, repository, unggahan
lib/core/storage/        adapter secure storage sesi
lib/core/errors/         AppError dan field issues
lib/core/theme/          token CSS web dan theme
lib/core/widgets/        panel, badge, daftar, dialog/form native yang dipakai ulang
lib/core/utils/          integer/BigInt, kg, Rupiah dan tanggal
lib/features/            definisi dan presentasi per domain ERP
assets/branding/         aset asli web
assets/fonts/            Inter v4.1, SIL OFL
android/ dan ios/         project native yang dihasilkan Flutter
test/                   unit, parser, API, auth, provider, form, navigation, golden
integration_test/        smoke test native dengan transport fixture terisolasi
tool/                    pemeriksaan release dan integritas file lama
```
Feature-first dengan Riverpod dan GoRouter. Layar koleksi memakai renderer native bersama supaya status, tombol, pagination, loading/error, serta perilaku form konsisten. Definisi form/aksi tiap domain tetap terpisah. Response data bersifat immutable; salinan formulir tidak mengubah data bacaan. Parsing HTTP berada di adapter/repository; mapping payload domain berada pada definisi fitur. Tidak ada kalkulasi stok, HPP, laba, atau saldo keuangan yang menjadi otoritas di Dart.
Gram, unit, dan Rupiah dikirim sebagai string bilangan bulat. Konversi kg memakai BigInt, bukan float. Selisih cek stok dan sisa sortir hanyalah bantuan presentasi; backend tetap memvalidasi dan melakukan perubahan stok. Tanggal bisnis awal berasal dari `/notifications`, sehingga mengikuti zona waktu organisasi tanpa menebak dari jam perangkat.
Dependensi langsung
Paket	Versi	Tanggung jawab
flutter_riverpod	3.4.3	state/provider
go_router	18.1.0	routing native
dio	5.11.1	HTTP/multipart
flutter_secure_storage	11.2.0	Keychain/Android secure storage
intl	0.20.3	format tanggal Indonesia
path_provider	2.1.6	direktori sementara privat
share_plus	13.3.1	native share/save PDF
image_picker	1.2.4	pemilihan foto galeri
url_launcher	6.3.3	membuka website eksternal
`flutter`, `flutter_localizations`, `flutter_test` dan `integration_test` berasal SDK. `pubspec.lock` dikirim untuk resolusi yang dapat direproduksi. Tidak ada Firebase, analytics, iklan, database mobile, atau paket antrean offline. Inter adalah keluarga font yang sudah disebut CSS web; lisensinya disertakan.
Autentikasi dan mutasi
Opaque cookie server (`__Host-tani_session` production; `tani_session` development) disimpan melalui secure storage, dibatasi ke origin API, maksimum 12 jam. CSRF hanya memori dan diambil ulang melalui `/auth/me`. Server tetap memeriksa batas idle dua jam, expiry, active user, organisasi dan role. Token/password tidak dicatat dalam log; password tidak disimpan. Tidak ada JWT atau autentikasi mobile baru.
401, `ACCOUNT_CHANGED`, dan `CSRF_REJECTED` membersihkan state lalu mengembalikan pengguna ke login. Role diperiksa ulang saat resume dan berkala ketika aplikasi aktif; sesudah transfer Owner role dimuat ulang secara eksplisit. Hak Owner juga disembunyikan untuk Admin, sementara policy server tetap menjadi pengaman sebenarnya.
Form membuat UUID v4 untuk mutasi domain. Bila jawaban terputus, payload dan key dibekukan di memori, input dikunci, dan pengguna dapat memilih retry manual dengan bytes/key yang sama. Tidak ada retry otomatis maupun antrean transaksi offline. Menutup form kehilangan draft tersebut: periksa catatan server sebelum membuat transaksi baru. Operasi password yang tidak idempotent tidak ditawarkan sebagai replay transaksi.
Undangan dan reset dapat memakai token fragment dari tautan. App Links/Universal Links belum dikonfigurasi pada domain penerbit. Login mobile sengaja tidak lagi menampilkan kontrol manual `Gunakan undangan Admin`/`Gunakan tautan pemulihan`; pengguna yang tidak memiliki undangan tidak perlu melihat jalur teknis tersebut. Sampai deep link native dikonfigurasi dan diverifikasi, link email harus tetap memiliki flow web yang valid. Route/token handling mobile dipertahankan untuk integrasi App Links/Universal Links berikutnya. Origin/path/token tetap wajib diperiksa.
Gambar dan PDF
Galeri native hanya menerima JPEG/PNG/WebP maksimum 5 MiB; server memvalidasi ulang dan reencode. Unggah tetap melalui multipart `/files` dengan field `image`, CSRF dan idempotency. Private image meminta otorisasi API dahulu, lalu mengambil signed URL HTTPS Filebase memakai HTTP client anonim tanpa cookie/CSRF/Origin. Tidak ada kredensial object storage di aplikasi.
`Unduh PDF` meminta JSON base64 dari server, memeriksa signature PDF dan nama file aman, menyimpan ke cache privat, lalu membuka lembar berbagi native (termasuk pilihan simpan yang tersedia pada OS). Tidak ada kalkulasi laporan baru atau izin storage luas. Cache ekspor lama dibersihkan setelah satu jam pada ekspor berikutnya, serta diupayakan dihapus ketika sesi berakhir. Berkas yang sudah disalin pengguna ke aplikasi lain mengikuti tujuan berbagi tersebut.
Pengujian
```sh
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test
flutter test --coverage
flutter pub outdated
```
Golden di `test/goldens` harus ditinjau terhadap sumber web sebelum pembaruan:
```sh
flutter test --update-goldens test/widgets/ui_golden_test.dart
flutter test test/widgets/ui_golden_test.dart
```
Smoke test native memakai fixture pada adapter HTTP, bukan database production:
```sh
flutter test integration_test/app_smoke_test.dart -d <emulator-or-device-id>
```
Lihat validation.md untuk hasil eksekusi yang benar-benar dilakukan dan batas lingkungan, serta ui-verification.md untuk bukti tampilan. Jangan menjalankan transaksi percobaan terhadap akun/database produksi.
Android dan iOS
Android debug:
```sh
flutter build apk --debug --dart-define=API_BASE_URL=https://erp.example.com
```
Android release tidak menggunakan debug signing. Sediakan empat environment variable di mesin penerbit: `TANI_KEYSTORE_PATH`, `TANI_KEYSTORE_PASSWORD`, `TANI_KEY_ALIAS`, `TANI_KEY_PASSWORD`. Jangan commit keystore, password, atau environment file.
```sh
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://erp.example.com \
  --obfuscate --split-debug-info=build/private-symbols
```
Task release menolak konfigurasi HTTP, API URL kosong, atau signing yang belum lengkap. Application ID/bundle ID awal adalah `id.podokoyo.tanidesa`; penerbit wajib memastikan kepemilikan dan identitas final sebelum distribusi pertama.
Untuk iOS, buka `ios/Runner.xcworkspace` pada macOS setelah `flutter pub get`, pilih development team/signing, pastikan entitlement Keychain cocok dengan bundle ID, lalu `flutter run` atau `flutter build ipa --release` dengan dart-define yang sama. Build phase melakukan preflight HTTPS. ATS tidak dilonggarkan. Project iOS disertakan, tetapi kompilasi/signing iOS memerlukan Xcode dan perangkat/simulator Apple.
Sebelum distribusi
Baca backend-constraints.md, security-audit.md, dan play-store-readiness.md. Native push belum tersedia dari backend; pengingat in-app dan email server yang telah dikonfigurasi tetap berlaku. Kebijakan privasi, proses data/retensi/penghapusan akun, signing, identitas domain, dan uji layanan staging harus diselesaikan penerbit. Dokumen ini tidak menyatakan aplikasi sudah lolos review store.