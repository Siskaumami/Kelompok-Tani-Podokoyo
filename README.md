# Kelompok Tani Podokoyo

Website publik dan sistem operasional/ERP berbasis web untuk Kelompok Tani Podokoyo.

Project ini menggabungkan dua kebutuhan dalam satu aplikasi:

1. **Website publik** untuk profil desa, anggota kelompok tani, dan katalog produk.
2. **ERP / ruang kerja internal** untuk pengelolaan panen, persediaan, produksi, penjualan, pembukuan, pengguna, dan aktivitas operasional.

Project dibangun sebagai aplikasi nyata, bukan demo. Data bisnis berasal dari database persisten dan tidak bergantung pada seed/mock data untuk penggunaan normal.

---

## Status Project

Status saat ini:

- Website publik: aktif secara fungsional.
- Dashboard ERP: aktif secara fungsional.
- Responsive desktop/tablet/mobile: tersedia.
- PWA / installable web app: tersedia.
- Offline transactional writes: **tidak didukung**.
- Database development: PostgreSQL lokal.
- Database production: dirancang untuk **Neon PostgreSQL**.
- Object storage: **Filebase S3-compatible storage**.
- Email: **Brevo**.
- Web Push: VAPID.
- Marketplace API: **tidak terintegrasi**.
- Penjualan marketplace: input manual.
- Deployment production: **belum dilakukan**.
- GitHub digunakan sebagai source repository, bukan sebagai database/runtime aplikasi.

Verifikasi terakhir:

```text
TypeScript typecheck: PASS

Test Files  3 passed | 1 skipped
Tests       32 passed | 2 skipped
Failed      0
```

Test dijalankan tanpa file parallelism untuk menjaga stabilitas PGlite:

```bash
npm test
```

yang saat ini menggunakan:

```text
vitest run --no-file-parallelism
```

---

# Fitur Utama

## Website Publik

Website publik dapat diakses tanpa login dan hanya menampilkan informasi yang memang dipublikasikan.

Halaman utama:

- Beranda
- Desa kami
- Para petani
- Produk

Fitur publik:

- profil desa;
- cerita kelompok tani;
- daftar anggota tani yang dipublikasikan;
- katalog produk;
- gambar produk;
- harga jual;
- tautan Shopee;
- tautan Tokopedia;
- tautan WhatsApp.

Data internal seperti HPP, stok internal, audit, dan catatan operasional tidak dikirim melalui API publik.

Marketplace pada versi ini hanya berupa tautan eksternal.

Tidak ada integrasi API Shopee atau Tokopedia.

---

# ERP / Ruang Kerja Internal

ERP berada di bawah area `/dashboard` dan membutuhkan autentikasi.

Modul utama:

- Ringkasan
- Panen
- Persediaan
- Produk & HPP
- Rencana produksi
- Hasil produksi
- Cek stok fisik
- Penjualan
- Pembukuan
- Konten website
- Pengguna
- Anggota tani
- Riwayat aktivitas
- Pengaturan

---

# Arsitektur

Project menggunakan pendekatan **modular monolith**.

```text
Browser / PWA
     |
     v
React + TypeScript
     |
     | REST JSON /api/v1
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

Frontend tidak berkomunikasi langsung dengan PostgreSQL.

Semua akses data bisnis dilakukan melalui backend.

---

# Tech Stack

## Frontend

- React
- TypeScript
- Vite
- React Router
- TanStack Query
- Zod
- Lucide React
- CSS

## Backend

- Node.js
- TypeScript
- Express
- REST JSON API
- Drizzle
- PostgreSQL

## Database

Development:

```text
PostgreSQL lokal
```

Production:

```text
Neon PostgreSQL
```

## Integrasi

- Brevo — email
- Filebase — S3-compatible storage
- Web Push / VAPID — notifikasi perangkat
- PDFKit — laporan PDF

---

# Struktur Project

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

database/
  migrations/

packages/
  shared/

tests/

docs/
```

### `apps/server`

Backend REST API dan domain logic.

### `apps/web`

Website publik dan dashboard ERP.

### `database/migrations`

Database schema dan migration PostgreSQL.

Migration tambahan saat ini mencakup antara lain:

- constraint satu Owner per organisasi;
- dukungan transfer Owner;
- consistency rule baru untuk cek stok fisik.

### `packages/shared`

Schema dan contract yang digunakan bersama frontend/backend.

### `tests`

Domain tests, API/security tests, formatting/transport tests, dan PostgreSQL integration test.

### `docs`

Dokumentasi arsitektur dan keputusan teknis yang lebih detail.

---

# Role dan Authorization

Terdapat tiga role pada level engineering.

## SUPER_ADMIN

Role internal/system.

Tidak digunakan sebagai role operasional normal dan tidak tersedia untuk assignment melalui dashboard organisasi.

## OWNER

Owner memiliki semua kemampuan operasional Admin ditambah:

- mengundang Admin;
- mengaktifkan/nonaktifkan Admin;
- mengelola pengaturan organisasi tertentu;
- memindahkan kepemilikan Owner ke Admin aktif.

## ADMIN

Admin dapat melakukan pekerjaan operasional normal tetapi:

- tidak dapat mengundang Admin;
- tidak dapat mengubah role pengguna;
- tidak dapat mengambil alih role Owner sendiri.

Authorization backend adalah sumber kebenaran.

Menyembunyikan tombol di frontend hanya untuk UX dan tidak menggantikan authorization server.

---

# Transfer Owner

Owner dapat memindahkan hak Owner kepada Admin yang aktif.

Transfer memiliki beberapa pengamanan:

- hanya Owner aktif yang dapat melakukan transfer;
- target harus Admin aktif dalam organisasi yang sama;
- Owner harus memasukkan password saat ini;
- perubahan role dilakukan dalam transaksi database;
- Owner lama berubah menjadi Admin;
- Admin target berubah menjadi Owner;
- database membatasi maksimum satu Owner per organisasi;
- undangan Admin aktif yang belum digunakan dipindahkan ke Owner baru;
- sesi Owner baru dicabut agar role baru digunakan melalui login baru;
- aktivitas transfer dicatat dalam audit log.

Transfer Owner tidak membuat dua Owner aktif sekaligus.

---

# Authentication

Autentikasi menggunakan:

```text
email + password
```

Fitur tersedia:

- login;
- logout;
- lupa password;
- reset password;
- ganti password;
- invitation Admin;
- session server-side.

Password baru untuk:

- aktivasi undangan;
- reset password;
- ganti password;

memerlukan minimum:

```text
12 karakter
```

dan maksimum:

```text
128 karakter
```

Password tidak disimpan plaintext.

Password diverifikasi menggunakan hashing modern pada backend.

Session web menggunakan cookie HttpOnly.

Pada production, cookie session menggunakan flag `Secure`.

Request mutasi juga dilindungi CSRF.

---

# Panen

Panen dicatat sebagai data fisik nyata.

Panen dapat memiliki:

- tanggal panen;
- petani;
- total panen;
- Grade A;
- Grade B;
- afkir/susut;
- catatan opsional.

Draf panen dapat belum selesai diklasifikasikan.

Panen baru memengaruhi persediaan setelah diselesaikan/finalized.

Finalisasi panen membuat movement persediaan, bukan menulis angka stok secara langsung.

---

# Persediaan

Persediaan menggunakan model **inventory ledger**.

Current balance berasal dari movement persediaan.

Stok tidak seharusnya diubah langsung secara arbitrer.

Contoh movement:

- hasil panen;
- penggunaan produksi;
- hasil produksi;
- penjualan;
- hasil cek stok;
- koreksi/pembatalan.

Pendekatan ini dipakai agar sistem dapat menjelaskan mengapa stok memiliki nilai tertentu.

---

# Cek Stok Fisik

Cek stok membandingkan:

```text
Stok tercatat
vs
Stok fisik
```

Aturan saat ini:

### Jika stok fisik sama dengan stok tercatat

```text
Selisih = 0
```

maka:

- alasan selisih tidak diperlukan;
- dropdown alasan dinonaktifkan;
- reason disimpan kosong/null;
- hasil ditampilkan sebagai `Sesuai`.

### Jika stok fisik berbeda

```text
Selisih != 0
```

maka:

- alasan selisih wajib dipilih.

Pilihan alasan mencakup antara lain:

- Susut / rusak
- Produksi gagal
- Kesalahan input sebelumnya
- Penjualan belum tercatat
- Produksi belum tercatat
- Barang hilang
- Lainnya

Jika memilih `Lainnya`, keterangan wajib diberikan.

Business rule ini tidak hanya dijaga frontend.

Backend dan database juga menjaga konsistensi hasil cek stok.

Cek stok menggunakan baseline revision sehingga pemeriksaan lama tidak dapat diam-diam menimpa transaksi stok yang lebih baru.

---

# Produk dan HPP

Produk memiliki:

- nama;
- kode produk;
- deskripsi;
- gambar;
- status publikasi;
- harga jual;
- kebutuhan kentang;
- biaya bahan;
- biaya kemasan;
- biaya produksi;
- biaya lain;
- tautan marketplace / WhatsApp.

HPP dibuat sederhana untuk kebutuhan usaha saat ini.

Riwayat harga dan HPP tetap dipertahankan agar perubahan harga hari ini tidak mengubah transaksi masa lalu.

---

# Produksi

Produksi dipisahkan menjadi dua konsep.

## Rencana Produksi

Rencana hanya mencatat kebutuhan/rencana penggunaan Grade B.

Rencana tidak mengurangi persediaan fisik.

## Hasil Produksi

Saat produksi benar-benar dilakukan:

- jumlah bahan aktual dicatat;
- Grade B dikurangi dari persediaan;
- finished goods ditambahkan;
- theoretical usage dan actual usage boleh berbeda;
- selisih produksi disimpan sebagai fakta operasional.

Sistem memodelkan kondisi fisik sebenarnya, bukan memaksa hasil produksi selalu sama dengan teori.

---

# Penjualan

Penjualan masih dicatat manual.

Channel tersedia:

- Offline
- WhatsApp
- Shopee
- Tokopedia

Marketplace API belum digunakan.

Penjualan dapat mencatat:

- tanggal;
- channel;
- nomor/reference pesanan;
- item;
- quantity;
- harga aktual;
- diskon;
- fee marketplace;
- catatan.

Penjualan produk jadi mengurangi persediaan secara transaksional.

Critical write menggunakan idempotency key agar retry request tidak membuat transaksi duplikat.

---

# Pembukuan

Pembukuan memberikan ringkasan operasional dan estimasi laba kotor.

Perhitungan menggunakan snapshot transaksi saat transaksi terjadi.

Perubahan harga/HPP produk di masa depan tidak mengubah histori transaksi lama.

PDF laporan menggunakan sumber calculation yang sama dengan laporan di layar.

Catatan:

```text
Estimasi laba kotor = pendapatan bersih - HPP
```

Modul ini bukan full accounting/general ledger.

---

# Audit Log

Aktivitas penting disimpan pada audit log.

Contohnya:

- panen dibuat/diselesaikan/dibatalkan;
- produk diubah;
- produksi dicatat;
- penjualan dicatat/dibatalkan;
- cek stok;
- perubahan user;
- invitation Admin;
- transfer Owner;
- perubahan pengaturan.

Riwayat bisnis tidak dihapus hanya untuk membuat tampilan lebih sederhana.

Pembatalan transaksi dilakukan melalui correction/reversal yang tetap dapat diaudit.

---

# PWA dan Offline

Aplikasi dapat dipasang sebagai PWA pada perangkat yang mendukung.

PWA menyediakan:

- manifest;
- icon;
- service worker;
- installable experience;
- push notification.

Tetapi aplikasi **tidak mendukung transaksi bisnis offline**.

Jika koneksi terputus:

```text
transaksi tidak disimpan dan tidak diantrikan secara offline
```

Hal ini disengaja untuk mencegah konflik stok dan transaksi saat beberapa pengguna bekerja bersamaan.

---

# Pengingat Penjualan

Sistem mendukung pengingat pencatatan penjualan harian.

Admin/Owner dapat mengkonfirmasi:

- selesai mencatat;
- tidak ada penjualan.

Konfirmasi menghentikan pengingat untuk tanggal tersebut tetapi bukan berarti buku/transaksi pada tanggal itu terkunci.

Transaksi tambahan tetap dapat dicatat.

Pengingat dapat bekerja melalui:

- in-app reminder;
- Web Push;
- email jika Brevo dikonfigurasi.

---

# Environment Variables

Jangan commit credential production ke repository.

Gunakan:

```text
.env.example
```

sebagai referensi variable.

File aktual:

```text
.env
.env.local-backup
```

harus tetap di-ignore Git.

Variable utama yang digunakan aplikasi:

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

---

# Local Development

## 1. Install dependency

```bash
npm install
```

## 2. Buat environment lokal

Salin:

```text
.env.example
```

menjadi:

```text
.env
```

Isi credential/configuration lokal yang diperlukan.

## 3. Jalankan PostgreSQL lokal

Gunakan PostgreSQL development lokal sesuai konfigurasi project.

Database development tidak boleh menggunakan database production tanpa sengaja.

## 4. Jalankan migration

```bash
npm run db:migrate
```

Migration harus selesai sebelum backend menggunakan schema terbaru.

## 5. Jalankan aplikasi development

Gunakan script development yang tersedia di `package.json`.

## 6. Typecheck

```bash
npm run typecheck
```

## 7. Test

```bash
npm test
```

---

# Database Migration

Migration bersifat append-only.

Jangan mengedit migration yang sudah pernah diterapkan pada environment lain hanya untuk mengubah hasil akhirnya.

Buat migration baru untuk perubahan schema berikutnya.

Sebelum deployment:

1. backup/verify database target bila diperlukan;
2. pastikan `DATABASE_MIGRATION_URL` mengarah ke database yang benar;
3. jalankan migration;
4. baru jalankan versi aplikasi terbaru.

Migration production harus diarahkan ke **Neon**, bukan PostgreSQL lokal.

---

# Production / Deployment

Repository GitHub menyimpan source code.

GitHub **bukan database production**.

Untuk production:

```text
GitHub Repository
      |
      v
Hosting / deployment service
      |
      +---- React frontend
      |
      +---- Node/Express backend
                |
                +---- Neon PostgreSQL
                +---- Filebase
                +---- Brevo
                +---- Web Push
```

Karena autentikasi web menggunakan server-managed cookie dan CSRF, deployment paling sederhana adalah frontend dan API berada pada origin/domain yang sama.

Production environment minimal harus memiliki:

```env
NODE_ENV=production
APP_URL=https://domain-production

DATABASE_URL=<Neon runtime connection>
DATABASE_MIGRATION_URL=<Neon migration connection jika diperlukan>

PUBLIC_ORG_SLUG=<slug organisasi>

BREVO_API_KEY=<secret>
EMAIL_FROM=<verified sender>

FILEBASE_ACCESS_KEY_ID=<secret>
FILEBASE_SECRET_ACCESS_KEY=<secret>
FILEBASE_BUCKET=<bucket>

VAPID_PUBLIC_KEY=<public key>
VAPID_PRIVATE_KEY=<secret>
VAPID_SUBJECT=<mailto atau URI valid>
```

`TRUST_PROXY_HOPS` harus disesuaikan dengan topologi hosting/reverse proxy yang digunakan.

Jangan menggunakan:

```text
localhost
PostgreSQL Docker lokal
credential development
```

untuk production.

---

# Git / Secret Safety

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
```

`.env.example` boleh di-commit selama hanya berisi placeholder.

Jika sebuah secret pernah telanjur masuk Git history, menghapus file pada commit berikutnya **tidak cukup**. Secret tersebut harus dianggap bocor dan di-rotate.

---

# Testing Strategy

Test diprioritaskan untuk business invariant dan security boundary, bukan mengejar jumlah test.

Area penting yang diuji antara lain:

- harvest balance;
- immutable inventory ledger;
- production planning vs actual production;
- stock tidak menjadi negatif;
- overselling prevention;
- historical price/HPP snapshot;
- sales idempotency;
- correction/reversal;
- stale stock-check protection;
- authorization Owner/Admin;
- tenancy/organization boundary;
- public/private data boundary;
- invitation token;
- password reset;
- reminder;
- integer transport;
- API security.

Status test terakhir:

```text
Test Files  3 passed | 1 skipped
Tests       32 passed | 2 skipped
Failed      0
```

PostgreSQL integration tests dapat di-skip pada test run biasa jika environment PostgreSQL integration tidak disediakan.

---

# Prinsip Business Integrity

Beberapa prinsip yang tidak boleh dirusak oleh perubahan berikutnya:

1. Inventory harus tetap ledger-based.
2. Planning tidak boleh dianggap sebagai penggunaan stok fisik.
3. Actual production harus mencatat kenyataan fisik.
4. Historical price dan HPP tidak boleh berubah setelah transaksi lama tercatat.
5. Critical writes harus tetap idempotent.
6. Authorization harus tetap authoritative di backend.
7. Public API tidak boleh membocorkan data internal.
8. Audit history harus tetap dapat dilacak.
9. Offline mode tidak boleh diam-diam menulis transaksi bisnis.
10. Perubahan satu domain harus diperiksa dampaknya pada domain lain.

---

# Change Impact Rule

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
tests
documentation
future mobile client
```

Perubahan lokal dianggap belum selesai jika merusak invariant sistem lain.

---

# Current Intentional Limitations

Versi saat ini sengaja tidak memiliki:

- Shopee API integration;
- Tokopedia API integration;
- marketplace synchronization;
- offline transactional write;
- native Android app;
- Flutter frontend;
- full accounting/general ledger;
- kompleksitas warehouse/manufacturing tingkat enterprise;
- runtime demo business data.

Pendekatan saat ini mengutamakan proses operasional yang sederhana dan bisa digunakan manusia tanpa membebani workflow.

---

# Future Direction

Backend dirancang agar tidak sepenuhnya tergantung pada React.

Jika nantinya dibutuhkan aplikasi Android, frontend Flutter dapat dibuat sebagai client baru terhadap backend API yang sama tanpa merombak business domain utama.

Marketplace integration juga dapat ditambahkan kemudian sebagai adapter yang menghasilkan internal sales transaction yang sama dengan input manual.

---

# Security Notes

Security penting yang sudah menjadi bagian arsitektur:

- server-side session;
- HttpOnly cookie;
- Secure cookie pada production;
- CSRF protection;
- password hashing;
- role-based authorization;
- organization scoping;
- idempotency;
- transaction boundary;
- database constraints;
- public/private DTO separation;
- sanitized production error;
- secrets melalui environment variables;
- invitation/reset token satu kali;
- session revocation pada perubahan security tertentu.

Tidak ada sistem yang dianggap aman hanya karena frontend menyembunyikan tombol.

Backend dan database tetap menjadi authority utama.

---

# Dokumentasi Lanjutan

Baca folder:

```text
docs/
```

sebelum melakukan perubahan arsitektur/domain yang signifikan.

Terutama perubahan yang menyentuh:

- inventory;
- production;
- historical pricing/HPP;
- authentication;
- authorization;
- reporting;
- database constraints;
- idempotency;
- concurrency;
- public API;
- deployment.

---

# Project Principle

> Bangun sistem paling sederhana yang benar-benar merepresentasikan kondisi bisnis nyata, menjaga histori dan keamanan, serta tidak membebani pengguna dengan kompleksitas teknis yang tidak memberi manfaat nyata.