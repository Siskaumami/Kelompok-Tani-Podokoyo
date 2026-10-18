# Hasil validasi implementasi

17 Oktober 2026. Semua perintah Flutter dijalankan dari `apps/mobile` menggunakan Flutter 3.47.7 / Dart 3.13.5, dengan `CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true`. Tidak ada akun, rahasia, atau database production yang dipakai.

## Pemeriksaan yang dieksekusi

| Perintah | Hasil akhir |
| --- | --- |
| `flutter pub get` | Berhasil, lockfile disertakan. |
| `flutter pub outdated --json` | Berhasil; hasil di dependency-review.json. Sembilan paket transitif memiliki versi lebih baru di luar resolusi/constraint saat pemeriksaan. Tidak dipaksa naik. Ini bukan audit CVE menyeluruh. |
| `dart format --output=none --set-exit-if-changed lib test integration_test tool` | Lulus: 70 file, 0 perubahan. |
| `flutter analyze --no-pub` | Lulus: No issues found. |
| `flutter test --no-pub --coverage --reporter expanded --timeout 45s` | Lulus: 148 tes, 0 gagal; termasuk 4 golden. Cakupan baris Dart yang terinstrumentasi: 2.302 / 2.687 = 85,67%. |
| `flutter build apk --debug --no-pub --dart-define=API_BASE_URL=https://example.com` | Lulus, exit 0: APK debug Android berhasil dibangun dari salinan sumber identik di workspace build terisolasi. |
| `python3 tool/verify_original_files.py` | Lulus: seluruh 124 file asli memiliki SHA-256 yang sama; tidak ada tambahan di luar apps/mobile. |

Alamat example.com hanya input konfigurasi build, bukan deployment ERP. Build tidak menjalankan transaksi jaringan. APK debug tidak disertakan pada paket sumber dan bukan artefak distribusi store.

## Scope tes

- Unit/parser: konfigurasi URL dan release HTTPS, envelope/tipe/UUID, integer/BigInt/kg/Rupiah, role, payload immutable dan format error.
- API/auth: login valid/invalid, cookie scope/expiry/flags/secure storage, CSRF dan Origin, restore/logout, revocation/ACCOUNT_CHANGED, transfer Owner, timeout, malformed receipt, retry manual dengan key dan payload identik.
- Domain/provider: panen/sortir, stok dan movement, produk/versi harga-HPP/Grade A, rencana dan hasil produksi, opname sesuai/selisih/stale, penjualan multi-barang/channel/diskon/fee/snapshot/pembatalan/konfirmasi harian, laporan/PDF, konten, pengguna, petani, audit, pengaturan.
- Widget: seluruh 14 layar pada 320×740 dan 1024×768, Owner/Admin, drawer/sidebar/logout, input/validasi/kondisional, loading/error/empty, invite-success menuju login baru, reset/ganti password, sesi habis ketika save, upload/retry dan PDF share adapter.
- Golden: products-phone, opnames-phone, workspace-tablet, login-phone. Font Inter dan MaterialIcons dimuat; hasil ditinjau terhadap sumber React/CSS. Lihat ui-verification.md.
- Keamanan file: signed-image client anonim dan host terbatas, upload size/signature, PDF base64/signature/filename dan direktori privat.

Fixture dan fake adapter sengaja terisolasi dari layanan nyata. Persentase cakupan bukan bukti runtime plugin native atau pengujian semua kombinasi bisnis backend.

## Perbaikan dari loop validasi

Overflow header 320 px dan teks besar diperbaiki dengan tinggi adaptif. Font tombol pada golden dikoreksi agar memakai Inter. Invalidation sesi ketika ganti password/save sempat memicu pembacaan private berulang; expiry kini idempotent, provider private memeriksa autentikasi, dan sesi dihapus sebelum refresh data. Respons write kosong/malformed diperlakukan sebagai hasil tidak pasti. Seluruh suite dijalankan ulang sesudah koreksi.

Build Android awal menemukan masalah lingkungan: Java hanya JRE tanpa javac, SDK tambahan belum tersedia, proxy cache lama, CA JDK berbeda dari CA sistem, serta cache transform/output sementara tidak konsisten. Build akhir memakai JDK 17 lengkap, Android SDK 35/36 + build-tools + NDK yang dibutuhkan Flutter, CA sistem yang valid, serta cache Gradle dan workspace build terisolasi. Input Dart, pubspec/lockfile dan Gradle dibandingkan byte-for-byte terhadap sumber final. Tidak ada perubahan TLS aplikasi atau certificate bypass.

APK akhir diperiksa dengan ZIP CRC, pemindaian entri sementara, header/tabel section seluruh 7 ELF native libraries, dan `aapt dump badging`. Package `id.podokoyo.tanidesa`, versi 1.0.0 (1), minimum SDK 24, target/compile SDK 36, ABI arm64-v8a/armeabi-v7a/x86_64. Manifest gabungan meminta INTERNET dan permission internal non-exported receiver; tidak ada izin kontak/lokasi/mikrofon/kamera/storage luas. APK debug berukuran 173.920.319 byte, SHA-256 `3834385ca20a8a3919dc67274d0f2707c87926f8096d984298e01d6930fe1303`. Pemeriksaan paket ini bukan bukti pengoperasian hardware.

## Batas lingkungan dan pemeriksaan yang belum dieksekusi

| Pemeriksaan | Status yang benar-benar diamati |
| --- | --- |
| `flutter devices --machine` | Hanya Linux desktop; project sengaja menargetkan Android/iOS. Tidak ada emulator/perangkat mobile terhubung. |
| `flutter test integration_test/app_smoke_test.dart --no-pub` | Tidak dapat dijalankan: tidak ada supported device. Test disertakan untuk emulator/perangkat, bukan diklaim lulus. |
| `flutter build ios` | Target/perintah build iOS tidak tersedia pada host Linux; Xcode/iOS SDK tidak ada. Plist/entitlement/privacy manifest dapat diparse, tetapi bukan kompilasi iOS. |
| Android release AAB / iOS IPA | Belum dibangun atau ditandatangani. Tidak ada signing key, Apple team, atau identitas store yang diberikan. Gate HTTPS diuji pada Dart; konfigurasi native harus diverifikasi penerbit. |
| Native picker, Keychain/secure storage, share sheet, app resume, deep-link OS | Masih memerlukan emulator/perangkat Android dan iPhone. Unit/widget memakai adapter/fake pada batas platform. |
| Staging/API nyata, email/worker, lintas klien, PDF/upload asli | Tidak dijalankan; tidak ada deployment/kredensial staging yang diberikan. Wajib smoke test sebelum distribusi. |

Tidak ada dukungan FCM/APNs pada server yang diberikan. Pengingat in-app tersedia; native push membutuhkan kontrak backend lain dan tidak dibuat secara palsu.

## Pemeriksaan monorepo asli

`npm ci --no-audit --no-fund`, `npm run typecheck`, `npm run lint`, `npm run test`, dan `npm run build` dijalankan pada salinan byte-identik terisolasi di bawah apps/mobile, kemudian salinan sementara dibuang. Typecheck dan build lulus; 32 tes lulus, 2 integration PostgreSQL dilewati tanpa database disposable. Lint memiliki 3 error yang sudah ada pada sumber asli. Detail tepatnya ada di legacy-checks.md. File asli tidak diubah untuk memperbaikinya karena batas tugas melarang perubahan tersebut.

No existing files outside apps/mobile were modified.
