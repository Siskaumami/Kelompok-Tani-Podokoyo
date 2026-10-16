# Tani Desa

Aplikasi operasional kelompok tani dan website publik. React + TypeScript, REST modular monolith Express, Drizzle/PostgreSQL/Neon, Cloudflare R2, Brevo, dan PWA. Warna utama `#e8fff0` dan aksen `#148339`.

**Tidak ada akun demo, seed bisnis, respons penyedia palsu, atau antrean transaksi offline.** Instalasi baru dimulai kosong. Seluruh data bisnis berasal dari catatan pengguna.

## Mulai dari sini

1. Gunakan Node.js **22.12+ atau 24+** dan PostgreSQL 17+ / Neon.
2. `npm ci`
3. Salin `.env.example` menjadi `.env`. Isi `DATABASE_URL` dan `APP_URL`. Untuk Neon gunakan TLS tervalidasi. Pilihan PostgreSQL lokal: isi `LOCAL_DB_PASSWORD`, jalankan `docker compose up -d db`, lalu isi URL database sesuai kredensial pilihan Anda.
4. `npm run db:migrate`
5. Buat akun platform dan organisasi/Owner sungguhan melalui [panduan bootstrap](docs/26-initial-bootstrap.md). Perintah ini sengaja tidak dijalankan saat startup.
6. Isi `PUBLIC_ORG_SLUG` dengan slug organisasi yang dibuat.
7. `npm run dev` → frontend `http://localhost:5173`, backend port 3000. Gunakan `APP_URL=http://localhost:5173`.
8. Masuk dengan Owner, tambah profil petani/produk nyata, catat panen, lalu finalisasi sortir untuk memasukkan stok.

Integrasi email, gambar, dan push memerlukan kredensial penyedia. Tanpa kredensial, fitur tersebut memberi kesalahan konfigurasi; modul lain tetap memakai PostgreSQL sungguhan. Reset kata sandi memakai antrean permintaan di database, diproses worker setiap menit; respons penerimaan antrean bukan klaim email sudah terkirim. [Konfigurasi & deployment](docs/19-deployment.md).

## Build dan pemeriksaan

```bash
npm run typecheck
npm run lint
npm test
npm run build
# Untuk membuka build lokal, APP_URL harus sesuai origin port 3000.
APP_URL=http://localhost:3000 NODE_ENV=development npm start
```

Uji kontensi multi-koneksi memerlukan `TEST_DATABASE_URL` untuk database khusus yang namanya berakhiran `_test`. Lihat [strategi pengujian](docs/20-testing-strategy.md). `npm test` tanpa variabel tersebut tetap menjalankan tes PostgreSQL WASM/PGlite dan API, lalu melewati dua tes kontensi native secara eksplisit.

## Fitur

* Website publik: beranda, profil desa, anggota, katalog, tautan Shopee/Tokopedia/WhatsApp; hanya data terbit.
* Panen draf/final, Grade A/B/afkir, ledger persediaan, pembatalan beralasan.
* Alokasi Grade B terpisah dari produksi nyata, kebutuhan teoritis dan selisih, produk jadi.
* Versi harga/HPP, snapshot penjualan multi-barang, diskon, biaya kanal, pembatalan.
* Stock opname dengan baseline/revisi, pengingat dan konfirmasi penjualan harian.
* Laporan harian/bulanan/tahunan/rentang khusus dan PDF dari perhitungan yang sama.
* Owner/Admin, undangan, sesi server, pemulihan/ganti kata sandi, audit, R2 terverifikasi, PWA.

## Struktur

| Lokasi | Tanggung jawab |
| --- | --- |
| `apps/server/src/modules` | Aturan domain dan integrasi |
| `apps/server/src/core` | Database, transaksi, RBAC, idempotensi, konfigurasi |
| `apps/web` | Antarmuka publik dan operasional |
| `packages/shared/src/schemas.ts` | Validasi kontrak input |
| `database/migrations` | Skema, constraints, indeks dan trigger |
| `scripts` | Migrasi, bootstrap, provisioning, job dan verifikasi ledger |
| `tests` | Fixture hanya untuk tes, domain/API/kontensi |
| `docs` | Arsitektur, aturan bisnis, API, deployment dan hasil review |

## Baca sebelum mengubah kode

[Arsitektur](docs/03-system-architecture.md) · [Model domain](docs/02-domain-model.md) · [Ledger](docs/05-inventory-ledger.md) · [Aturan AI/developer](docs/21-ai-development-rules.md) · [Review arsitektur](docs/22-architecture-review.md) · [Review keamanan](docs/23-security-review.md) · [Trade-off](docs/24-known-tradeoffs.md) · [OpenAPI](docs/openapi.json).

> BEFORE APPLYING ANY CHANGE, IDENTIFY WHICH DOMAINS, DATABASE INVARIANTS, API CONTRACTS, REPORTS, SECURITY BOUNDARIES, AND CLIENTS ARE AFFECTED. A CHANGE IS NOT COMPLETE UNTIL ITS SYSTEM-WIDE IMPACT HAS BEEN REVIEWED.

Aplikasi ini menyediakan codebase untuk dikonfigurasi dan di-deploy. Kredensial produksi tidak disertakan. Pembukuan berupa laporan operasional, bukan general ledger akuntansi penuh. Baca batas verifikasi pada dokumen review sebelum go-live.
