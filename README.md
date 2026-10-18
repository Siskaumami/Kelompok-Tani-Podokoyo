Kelompok Tani Podokoyo
Website publik, ERP operasional berbasis web, dan klien mobile Flutter untuk Kelompok Tani Podokoyo.
Project ini menggabungkan tiga kebutuhan utama:
Website publik untuk profil desa, anggota kelompok tani, dan katalog produk.
ERP / ruang kerja internal untuk pengelolaan panen, persediaan, produksi, penjualan, pembukuan, pengguna, dan aktivitas operasional.
Aplikasi mobile Flutter sebagai klien native Android/iOS terhadap backend ERP yang sama.
Project dibangun sebagai aplikasi nyata, bukan demo. Data bisnis berasal dari database persisten dan tidak bergantung pada seed/mock data untuk penggunaan normal.
---
Status Project
Status saat ini:
Website publik: aktif secara fungsional.
Dashboard ERP web: aktif secara fungsional.
Responsive desktop/tablet/mobile untuk web: tersedia.
PWA / installable web app: tersedia.
Flutter mobile client: tersedia di `apps/mobile`.
Android Flutter: sudah berhasil dijalankan secara lokal pada emulator Android 16 dalam profile mode.
iOS Flutter project: tersedia, tetapi build/signing iOS tetap memerlukan macOS/Xcode dan belum dianggap tervalidasi hanya dari environment Windows.
App Links / Universal Links untuk membuka undangan/reset langsung dari email ke aplikasi: belum dikonfigurasi.
Native push FCM/APNs: belum tersedia; pengingat server/email/web push tetap terpisah dari native push.
Offline transactional writes: tidak didukung pada web maupun mobile.
Database development: PostgreSQL lokal.
Database production: dirancang untuk Neon PostgreSQL.
Object storage: Filebase S3-compatible storage.
Email: Brevo.
Web Push: VAPID.
Marketplace API: tidak terintegrasi.
Penjualan marketplace: input manual.
Deployment production / store distribution: belum dilakukan.
GitHub digunakan sebagai source repository, bukan sebagai database/runtime aplikasi.
Sebelum push/release, verifikasi ulang kondisi source saat ini. Jangan mengandalkan angka test lama yang tertulis pada review historis.
Untuk web/backend:
```bash
npm run typecheck
npm test
npm run build
```
Untuk mobile:
```bash
cd apps/mobile
flutter analyze
flutter test
```
---
Fitur Utama
Website Publik
Website publik dapat diakses tanpa login dan hanya menampilkan informasi yang memang dipublikasikan.
Halaman utama:
Beranda
Desa kami
Para petani
Produk
Fitur publik:
profil desa;
cerita kelompok tani;
daftar anggota tani yang dipublikasikan;
katalog produk;
gambar produk;
harga jual;
tautan Shopee;
tautan Tokopedia;
tautan WhatsApp.
Data internal seperti HPP, stok internal, audit, dan catatan operasional tidak dikirim melalui API publik.
Marketplace pada versi ini hanya berupa tautan eksternal. Tidak ada integrasi API Shopee atau Tokopedia.
---
ERP / Ruang Kerja Internal
ERP membutuhkan autentikasi dan tersedia melalui dashboard web serta klien mobile Flutter.
Pada web, area internal berada di bawah `/dashboard`.
Modul utama:
Ringkasan
Panen
Persediaan
Produk & HPP
Rencana produksi
Hasil produksi
Cek stok fisik
Penjualan
Pembukuan
Konten website
Pengguna
Anggota tani
Riwayat aktivitas
Pengaturan
Urutan dan business rule utama dijaga konsisten antara web dan mobile. Perbedaan presentasi diperbolehkan selama tidak mengubah kontrak API atau aturan domain.
---
Arsitektur
Project menggunakan pendekatan modular monolith pada backend dengan lebih dari satu client.
```text
Browser / PWA                    Android / iOS
     |                                |
     v                                v
React + TypeScript                Flutter + Dart
     |                                |
     +------------- REST JSON /api/v1-+
                      |
                      v
               Node.js / Express
                      |
                      +---- PostgreSQL
                      |       Local development -> PostgreSQL lokal
                      |       Production        -> Neon PostgreSQL
                      |
                      +---- Filebase
                      |       S3-compatible object storage
                      |
                      +---- Brevo
                      |       Email invitation / reset / notification
                      |
                      +---- Web Push
                              VAPID
```
Frontend web dan mobile tidak berkomunikasi langsung dengan PostgreSQL.
Semua akses dan business rule utama dilakukan melalui backend. Flutter bukan backend kedua dan tidak menduplikasi authority stok, HPP, laporan, role, atau transaksi.
---
Tech Stack
Web Frontend
React
TypeScript
Vite
React Router
TanStack Query
Zod
Lucide React
CSS
Mobile Frontend
Flutter
Dart
Riverpod
GoRouter
Dio
Flutter Secure Storage
intl
image_picker
share_plus
url_launcher
Mobile menggunakan API backend yang sama. Tidak ada database bisnis lokal dan tidak ada antrean transaksi offline.
Backend
Node.js
TypeScript
Express
REST JSON API
Drizzle
PostgreSQL
Database
Development:
```text
PostgreSQL lokal
```
Production:
```text
Neon PostgreSQL
```
Integrasi
Brevo — email
Filebase — S3-compatible storage
Web Push / VAPID — notifikasi browser
PDFKit — laporan PDF
---
Struktur Project
Struktur utama:
```text
apps/
  server/
    src/
      core/
      modules/

  web/
    public/
    src/

  mobile/
    android/
    ios/
    lib/
    test/
    integration_test/
    docs/

database/
  migrations/

packages/
  shared/

tests/

docs/
```
`apps/server`
Backend REST API dan domain logic.
`apps/web`
Website publik dan dashboard ERP web.
`apps/mobile`
Klien Flutter native Android/iOS untuk ERP. Client ini menggunakan backend/API yang sama dan tidak memiliki business engine terpisah.
`database/migrations`
Database schema dan migration PostgreSQL.
Migration tambahan saat ini mencakup antara lain:
constraint satu Owner per organisasi;
dukungan transfer Owner;
consistency rule untuk cek stok fisik.
`packages/shared`
Schema/contract yang digunakan backend/web. Flutter tetap mengikuti kontrak API yang sama walaupun implementasi modelnya berada di code Dart.
`tests`
Domain tests, API/security tests, formatting/transport tests, dan PostgreSQL integration test.
`docs`
Dokumentasi arsitektur, domain, security, deployment, dan keputusan teknis yang lebih detail.
---
Role dan Authorization
Terdapat tiga role pada level engineering.
SUPER_ADMIN
Role internal/system.
Tidak digunakan sebagai role operasional normal dan tidak tersedia untuk assignment melalui dashboard organisasi.
OWNER
Owner memiliki semua kemampuan operasional Admin ditambah:
mengundang Admin;
mengaktifkan/nonaktifkan Admin;
mengelola pengaturan organisasi tertentu;
memindahkan kepemilikan Owner ke Admin aktif.
ADMIN
Admin dapat melakukan pekerjaan operasional normal tetapi:
tidak dapat mengundang Admin;
tidak dapat mengubah role pengguna;
tidak dapat mengambil alih role Owner sendiri.
Authorization backend adalah sumber kebenaran.
Menyembunyikan tombol di web/mobile hanya untuk UX dan tidak menggantikan authorization server.
---
Transfer Owner
Owner dapat memindahkan hak Owner kepada Admin yang aktif melalui flow yang tersedia di aplikasi.
Transfer memiliki beberapa pengamanan:
hanya Owner aktif yang dapat melakukan transfer;
target harus Admin aktif dalam organisasi yang sama;
Owner harus memasukkan password saat ini;
perubahan role dilakukan dalam transaksi database;
Owner lama berubah menjadi Admin;
Admin target berubah menjadi Owner;
database membatasi maksimum satu Owner per organisasi;
undangan Admin aktif yang belum digunakan dipindahkan ke Owner baru;
sesi Owner baru dicabut agar role baru digunakan melalui login baru;
aktivitas transfer dicatat dalam audit log.
Transfer Owner tidak membuat dua Owner aktif sekaligus.
---
Authentication
Autentikasi menggunakan:
```text
email + password
```
Fitur tersedia:
login;
logout;
lupa password;
reset password;
ganti password;
invitation Admin;
session server-side.
Password baru untuk aktivasi undangan, reset password, dan ganti password memerlukan minimum 12 karakter dan maksimum 128 karakter.
Password tidak disimpan plaintext dan diverifikasi menggunakan hashing backend.
Web
Session web menggunakan cookie HttpOnly. Pada production cookie menggunakan flag `Secure`. Request mutasi dilindungi Origin/CSRF.
Mobile
Mobile menggunakan opaque session yang sama melalui transport API dan menyimpan material sesi yang diperlukan di secure storage. CSRF tetap dikelola sebagai state sementara dan authorization tetap ditentukan server.
Jangan menaruh API key, password, database credential, atau secret server dalam `--dart-define`; nilai build aplikasi dapat dibaca dari binary.
App Links / Universal Links belum dikonfigurasi. UI login mobile tidak menampilkan tombol paste undangan/reset manual. Sampai deep link native selesai, link email tetap harus memiliki flow web yang valid.
---
Panen
Panen dicatat sebagai data fisik nyata.
Panen dapat memiliki:
tanggal panen;
petani;
total panen;
Grade A;
Grade B;
afkir/susut;
catatan opsional.
Draf panen dapat belum selesai diklasifikasikan.
Panen baru memengaruhi persediaan setelah diselesaikan/finalized.
Finalisasi panen membuat movement persediaan, bukan menulis angka stok secara langsung.
---
Persediaan
Persediaan menggunakan model inventory ledger.
Current balance berasal dari movement persediaan. Stok tidak seharusnya diubah langsung secara arbitrer.
Contoh movement:
hasil panen;
penggunaan produksi;
hasil produksi;
penjualan;
hasil cek stok;
koreksi/pembatalan.
Pendekatan ini dipakai agar sistem dapat menjelaskan mengapa stok memiliki nilai tertentu.
---
Cek Stok Fisik
Cek stok membandingkan:
```text
Stok tercatat
vs
Stok fisik
```
Jika stok fisik sama dengan stok tercatat
```text
Selisih = 0
```
maka:
alasan selisih tidak diperlukan;
dropdown alasan dinonaktifkan;
reason disimpan kosong/null;
hasil ditampilkan sebagai `Sesuai`.
Jika stok fisik berbeda
```text
Selisih != 0
```
maka alasan selisih wajib dipilih.
Pilihan alasan mencakup antara lain:
Susut / rusak
Produksi gagal
Kesalahan input sebelumnya
Penjualan belum tercatat
Produksi belum tercatat
Barang hilang
Lainnya
Jika memilih `Lainnya`, keterangan wajib diberikan.
Business rule ini tidak hanya dijaga frontend. Backend dan database juga menjaga konsistensi hasil cek stok.
Cek stok menggunakan baseline revision sehingga pemeriksaan lama tidak dapat diam-diam menimpa transaksi stok yang lebih baru.
---
Produk dan HPP
Produk memiliki:
nama;
kode produk;
deskripsi;
gambar;
status publikasi;
harga jual;
kebutuhan kentang;
biaya bahan;
biaya kemasan;
biaya produksi;
biaya lain;
tautan marketplace / WhatsApp.
HPP dibuat sederhana untuk kebutuhan usaha saat ini.
Riwayat harga dan HPP tetap dipertahankan agar perubahan harga hari ini tidak mengubah transaksi masa lalu.
---
Produksi
Produksi dipisahkan menjadi dua konsep.
Rencana Produksi
Rencana hanya mencatat kebutuhan/rencana penggunaan Grade B.
Rencana tidak mengurangi persediaan fisik.
Hasil Produksi
Saat produksi benar-benar dilakukan:
jumlah bahan aktual dicatat;
Grade B dikurangi dari persediaan;
finished goods ditambahkan;
theoretical usage dan actual usage boleh berbeda;
selisih produksi disimpan sebagai fakta operasional.
Sistem memodelkan kondisi fisik sebenarnya, bukan memaksa hasil produksi selalu sama dengan teori.
---
Penjualan
Penjualan masih dicatat manual.
Channel tersedia:
Offline
WhatsApp
Shopee
Tokopedia
Marketplace API belum digunakan.
Penjualan dapat mencatat:
tanggal;
channel;
nomor/reference pesanan;
item;
quantity;
harga aktual;
diskon;
fee marketplace;
catatan.
Penjualan produk jadi mengurangi persediaan secara transaksional.
Critical write menggunakan idempotency key agar retry request tidak membuat transaksi duplikat.
---
Pembukuan
Pembukuan memberikan ringkasan operasional dan estimasi laba kotor.
Perhitungan menggunakan snapshot transaksi saat transaksi terjadi.
Perubahan harga/HPP produk di masa depan tidak mengubah histori transaksi lama.
PDF laporan menggunakan sumber calculation yang sama dengan laporan di layar.
```text
Estimasi laba kotor = pendapatan bersih - HPP
```
Modul ini bukan full accounting/general ledger.
---
Audit Log
Aktivitas penting disimpan pada audit log, termasuk panen, produk, produksi, penjualan, cek stok, perubahan user, invitation Admin, transfer Owner, dan perubahan pengaturan.
Riwayat bisnis tidak dihapus hanya untuk membuat tampilan lebih sederhana.
Pembatalan transaksi dilakukan melalui correction/reversal yang tetap dapat diaudit.
---
PWA, Mobile, dan Offline
PWA Web
PWA menyediakan manifest, icon, service worker, installable experience, dan web push pada browser yang mendukung.
Service worker tidak boleh mengantrikan transaction write.
Flutter Mobile
Flutter berada di `apps/mobile` dan menggunakan backend REST yang sama.
Mobile tidak memiliki database transaksi offline dan tidak menyimpan write untuk dikirim kemudian.
Jika koneksi terputus:
```text
transaksi tidak disimpan dan tidak diantrikan secara offline
```
Hal ini disengaja untuk mencegah konflik stok dan transaksi saat beberapa pengguna bekerja bersamaan.
Website publik tetap dibuka melalui browser eksternal; tidak ada WebView yang menjadi business layer baru.
---
Pengingat Penjualan
Sistem mendukung pengingat pencatatan penjualan harian.
Admin/Owner dapat mengkonfirmasi:
selesai mencatat;
tidak ada penjualan.
Konfirmasi menghentikan pengingat untuk tanggal tersebut tetapi bukan berarti buku/transaksi pada tanggal itu terkunci.
Transaksi tambahan tetap dapat dicatat.
Pengingat dapat bekerja melalui:
in-app reminder;
Web Push;
email jika Brevo dikonfigurasi.
Native push FCM/APNs belum menjadi bagian backend saat ini.
---
Environment Variables
Jangan commit credential production ke repository.
Gunakan `.env.example` sebagai referensi environment backend/web.
File aktual seperti `.env` dan `.env.local-backup` harus tetap di-ignore Git.
Variable utama server:
```env
NODE_ENV=
PORT=
APP_URL=

DATABASE_URL=
DATABASE_MIGRATION_URL=

PUBLIC_ORG_SLUG=
TRUST_PROXY_HOPS=

BREVO_API_KEY=
EMAIL_FROM=
EMAIL_FROM_NAME=

FILEBASE_ACCESS_KEY_ID=
FILEBASE_SECRET_ACCESS_KEY=
FILEBASE_BUCKET=

VAPID_PUBLIC_KEY=
VAPID_PRIVATE_KEY=
VAPID_SUBJECT=

BACKGROUND_WORKER_ENABLED=
REMINDER_WORKER_ENABLED=
```
Jangan menaruh credential asli dalam `.env.example`.
Mobile build configuration
Mobile memakai build-time configuration, terutama:
```text
API_BASE_URL
APP_ORIGIN
```
Contoh development dengan Android Emulator ketika backend berjalan pada Windows host port `3000` dan web origin pada `5173`:
```powershell
flutter run --profile -d <emulator-id> `
  --dart-define=API_BASE_URL=http://10.0.2.2:3000 `
  --dart-define=APP_ORIGIN=http://localhost:5173
```
`10.0.2.2` adalah alamat host dari Android Emulator. Jangan mengganti `APP_ORIGIN` hanya untuk membuat link browser emulator bekerja; origin tersebut juga dipakai untuk pemeriksaan request backend.
---
Local Development
1. Install dependency web/backend
```bash
npm install
```
2. Buat environment lokal
Salin `.env.example` menjadi `.env`, lalu isi konfigurasi lokal yang diperlukan.
3. Jalankan PostgreSQL lokal
Gunakan PostgreSQL development lokal sesuai konfigurasi project.
Database development tidak boleh menggunakan database production tanpa sengaja.
4. Jalankan migration
```bash
npm run db:migrate
```
5. Jalankan web/backend
Gunakan script development yang tersedia di `package.json`.
6. Verifikasi web/backend
```bash
npm run typecheck
npm test
npm run build
```
7. Jalankan Flutter mobile
```bash
cd apps/mobile
flutter doctor -v
flutter pub get
flutter devices
```
Kemudian jalankan dengan konfigurasi backend yang sesuai environment.
Untuk Android Emulator terhadap backend lokal host Windows, gunakan `10.0.2.2`, bukan `localhost`.
8. Verifikasi Flutter
```bash
flutter analyze
flutter test
```
Jangan menjalankan dua `flutter run` terhadap AVD yang sama secara bersamaan.
---
Database Migration
Migration bersifat append-only.
Jangan mengedit migration yang sudah pernah diterapkan pada environment lain hanya untuk mengubah hasil akhirnya.
Buat migration baru untuk perubahan schema berikutnya.
Sebelum deployment:
backup/verify database target bila diperlukan;
pastikan `DATABASE_MIGRATION_URL` mengarah ke database yang benar;
jalankan migration;
baru jalankan versi aplikasi terbaru.
Migration production harus diarahkan ke Neon, bukan PostgreSQL lokal.
---
Production / Deployment
Repository GitHub menyimpan source code. GitHub bukan database production.
Arsitektur deployment:
```text
GitHub Repository
      |
      +-----------------------+
      |                       |
      v                       v
Web/API deployment       Mobile release pipeline
      |                       |
      +---- React frontend    +---- Android App Bundle/APK
      +---- Node backend      +---- iOS IPA (macOS/Xcode)
              |
              +---- Neon PostgreSQL
              +---- Filebase
              +---- Brevo
              +---- Web Push
```
Karena autentikasi web menggunakan server-managed cookie dan CSRF, deployment web paling sederhana adalah frontend dan API pada origin/domain yang sama.
Mobile tetap mengakses API melalui HTTPS production dan harus menggunakan `API_BASE_URL`/`APP_ORIGIN` yang sesuai deployment.
Production environment minimal server harus memiliki konfigurasi database, public slug, Brevo, Filebase, dan VAPID sesuai fitur yang diaktifkan.
`TRUST_PROXY_HOPS` harus disesuaikan dengan topologi hosting/reverse proxy yang digunakan.
Jangan menggunakan `localhost`, PostgreSQL Docker lokal, atau credential development untuk production.
App Links/Universal Links, signing, store metadata, dan smoke test device nyata merupakan gate terpisah sebelum distribusi mobile.
---
Git / Secret Safety
Sebelum push:
```bash
git status
git diff --check
```
Pastikan file seperti berikut tidak ikut commit:
```text
.env
.env.local-backup
node_modules/
credential files
private keys
keystore/password
mobile private symbols
```
`.env.example` boleh di-commit selama hanya berisi placeholder.
Jika sebuah secret pernah telanjur masuk Git history, menghapus file pada commit berikutnya tidak cukup. Secret tersebut harus dianggap bocor dan di-rotate.
---
Testing Strategy
Test diprioritaskan untuk business invariant dan security boundary, bukan mengejar jumlah test.
Area penting antara lain:
harvest balance;
immutable inventory ledger;
production planning vs actual production;
stock tidak menjadi negatif;
overselling prevention;
historical price/HPP snapshot;
sales idempotency;
correction/reversal;
stale stock-check protection;
authorization Owner/Admin;
tenancy/organization boundary;
public/private data boundary;
invitation token;
password reset;
reminder;
integer transport;
API security;
mobile parsing/config/auth/session;
mobile widget/navigation/form behavior.
PostgreSQL integration tests dapat di-skip pada test run biasa jika environment PostgreSQL integration tidak disediakan. Jangan menyamakan widget test dengan validasi perangkat nyata.
---
Prinsip Business Integrity
Beberapa prinsip yang tidak boleh dirusak oleh perubahan berikutnya:
Inventory harus tetap ledger-based.
Planning tidak boleh dianggap sebagai penggunaan stok fisik.
Actual production harus mencatat kenyataan fisik.
Historical price dan HPP tidak boleh berubah setelah transaksi lama tercatat.
Critical writes harus tetap idempotent.
Authorization harus tetap authoritative di backend.
Public API tidak boleh membocorkan data internal.
Audit history harus tetap dapat dilacak.
Offline mode tidak boleh diam-diam menulis transaksi bisnis.
Web dan mobile harus mengikuti domain rule yang sama.
Perubahan satu domain harus diperiksa dampaknya pada domain lain.
---
Change Impact Rule
Sebelum menganggap suatu perubahan selesai, periksa dampaknya terhadap:
```text
domain logic
database schema
migration
inventory
harvest
production
HPP
pricing history
sales
reporting
audit
authentication
authorization
public API
idempotency
concurrency
PWA
Flutter mobile client
tests
documentation
deployment
```
Perubahan lokal dianggap belum selesai jika merusak invariant sistem lain atau membuat web/mobile berbeda secara business rule tanpa alasan yang disengaja.
---
Current Intentional Limitations
Versi saat ini sengaja tidak memiliki:
Shopee API integration;
Tokopedia API integration;
marketplace synchronization;
offline transactional write;
native push FCM/APNs;
App Links/Universal Links production yang terverifikasi;
full accounting/general ledger;
kompleksitas warehouse/manufacturing tingkat enterprise;
runtime demo business data;
store release Android/iOS yang sudah dipublikasikan.
Project sudah memiliki Flutter mobile client, sehingga Flutter/native app tidak lagi termasuk limitation/future-only item.
---
Future Direction
Prioritas evolusi berikutnya dapat mencakup:
production deployment web/API;
Android/iOS signing dan distribusi;
Android App Links dan iOS Universal Links untuk invite/reset langsung dari email;
pengujian pada perangkat Android low/mid/high-end dan perangkat iOS;
native push hanya jika benar-benar dibutuhkan;
marketplace integration sebagai adapter yang menghasilkan internal sales transaction yang sama dengan input manual.
Backend tetap harus frontend-agnostic. React dan Flutter adalah client terhadap domain/backend yang sama, bukan dua sumber kebenaran terpisah.
---
Security Notes
Security penting yang menjadi bagian arsitektur:
server-side session;
HttpOnly/Secure cookie untuk web;
secure storage untuk material sesi mobile yang diperlukan;
CSRF/Origin protection;
password hashing;
role-based authorization;
organization scoping;
idempotency;
transaction boundary;
database constraints;
public/private DTO separation;
sanitized production error;
secrets melalui environment variables;
invitation/reset token satu kali;
session revocation pada perubahan security tertentu;
private Filebase object storage dengan signed access;
tidak ada secret server di bundle web/mobile.
Tidak ada sistem yang dianggap aman hanya karena frontend menyembunyikan tombol.
Backend dan database tetap menjadi authority utama.
---
Dokumentasi Lanjutan
Baca folder:
```text
docs/
apps/mobile/docs/
```
sebelum melakukan perubahan arsitektur/domain yang signifikan.
Terutama perubahan yang menyentuh inventory, production, historical pricing/HPP, authentication, authorization, reporting, database constraints, idempotency, concurrency, public API, mobile transport, dan deployment.
---
Project Principle
> Bangun sistem paling sederhana yang benar-benar merepresentasikan kondisi bisnis nyata, menjaga histori dan keamanan, serta tidak membebani pengguna dengan kompleksitas teknis yang tidak memberi manfaat nyata.