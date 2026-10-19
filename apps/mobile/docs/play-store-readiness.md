# Persiapan distribusi Google Play / iOS

Aplikasi membantu pengelola kelompok tani mencatat panen, persediaan, produksi, penjualan dan pembukuan memakai akun organisasi yang diundang. Tidak ada pendaftaran publik, pembayaran di aplikasi, iklan atau marketplace API. Dokumen ini inventaris teknis untuk penerbit, bukan pernyataan telah lolos kebijakan store.

## Akun, data dan jaringan

Akun email/password yang sudah disediakan atau diaktifkan lewat undangan diperlukan. Pengguna memakai role Admin/Pengelola Utama. Data yang diproses meliputi nama/email akun; profil petani/desa; foto yang dipilih; catatan panen/stok/produksi; transaksi, nominal dan referensi pesanan; laporan; serta jejak aktivitas. Backend dapat mengirim email akun/pengingat melalui konfigurasi organisasi.

Semua komunikasi release memakai HTTPS ke backend yang dikonfigurasi. Sesi opaque disimpan melalui Keychain/Android secure storage, CSRF hanya memori, password tidak dipersistenkan. Gambar menggunakan API dan signed URL HTTPS Filebase tanpa meneruskan sesi ke object storage. PDF disimpan sementara di cache privat dan dibagikan hanya setelah aksi pengguna. Link website dibuka di browser eksternal.

## Izin dan kemampuan

| Kemampuan | Implementasi |
| --- | --- |
| Internet | Diperlukan ERP online; tidak ada transactional offline queue |
| Foto | Native system gallery/photo picker; hanya foto yang dipilih, JPEG/PNG/WebP <=5 MiB; iOS usage string disediakan |
| Kamera | Tidak dipakai; tidak ada tombol kamera atau permintaan izin kamera |
| Storage luas / manage external storage | Tidak diminta; PDF memakai direktori sementara dan native share sheet |
| Push notification native | Tidak tersedia pada backend; tidak meminta POST_NOTIFICATIONS untuk fitur yang tidak ada |
| Pengingat | Ditampilkan di aplikasi dari state server; email mengikuti pengaturan server |
| Analytics / advertising ID / ads | Tidak ditambahkan |
| Lokasi / background location | Tidak diakses |
| Kontak / mikrofon | Tidak diakses |
| Background financial synchronization | Tidak ada |

Periksa merged manifest final dan perilaku semua plugin pada perangkat release. Flutter runtime dan plugin sistem tidak boleh dianggap sebagai analytics aplikasi tanpa bukti. Penerbit tetap bertanggung jawab menilai SDK/provider yang dipakai deployment final.

## Bahan deklarasi Data Safety

Periksa ulang terhadap [petunjuk resmi Data safety Google Play](https://support.google.com/googleplay/android-developer/answer/10787469), diakses 17 Oktober 2026. Kandidat data yang perlu dinilai adalah informasi pribadi akun, foto/konten pengguna, aktivitas aplikasi dan data transaksi usaha. Pengumpulan ini mendukung fungsi aplikasi/manajemen akun; kode mobile tidak memakai data untuk iklan, tracking atau profil marketing. Hosting, object storage, email, retensi server, serta kontrak pemroses perlu dinilai penerbit. Jangan menyimpulkan deklarasi “tidak mengumpulkan data” hanya karena tidak memasang analytics.

Native share PDF terjadi atas pilihan pengguna. Tentukan bagaimana pengecualian berbagi yang relevan berlaku menurut panduan store, alih-alih mengklaim semua provider bukan penerima data. Enkripsi in transit tersedia pada kode release; keamanan deployment/certificate/domain masih perlu diverifikasi.

Aktivasi undangan membuat akun melalui backend. Penghapusan akun sekarang tersedia untuk Admin melalui aplikasi mobile dan halaman web publik `/account-deletion`. Penghapusan memerlukan kata sandi saat ini, mencabut seluruh sesi, membersihkan data autentikasi terkait organisasi, menonaktifkan akun, dan menganonimkan nama serta email akun. Catatan transaksi dan audit organisasi tetap mempertahankan referensi pengguna yang sudah dianonimkan untuk menjaga integritas pembukuan dan keamanan. Pengelola Utama harus memindahkan peran Pengelola Utama ke Admin lain sebelum dapat menghapus akun. Implementasi mengikuti kebutuhan proses penghapusan di dalam dan di luar aplikasi sebagaimana dijelaskan pada [persyaratan penghapusan akun Google Play](https://support.google.com/googleplay/android-developer/answer/13327111).

## Dependensi dan privacy

Paket langsung dan versi tercantum di README, lockfile disertakan. Riverpod, GoRouter, Dio, secure storage, intl, path_provider, share_plus, image_picker dan url_launcher mempunyai tanggung jawab berbeda; tidak ada Firebase atau SDK iklan/analytics baru. Font Inter dan lisensi OFL disertakan. Branding memakai aset asli proyek.

Kebijakan privasi tersedia pada halaman publik `/privacy` dan dapat dibuka dari aplikasi mobile. Kebijakan menjelaskan kategori data, tujuan pemrosesan, penyedia layanan, keamanan, retensi, serta penghapusan akun/data. Halaman `/account-deletion` menyediakan jalur web untuk memulai penghapusan akun tanpa memerlukan aplikasi Android terpasang. Untuk iOS, tinjau privacy labels, manifest privacy aplikasi/dependensi dan photo-library usage string pada archive final; manifest yang disertakan tidak mengklaim tracking.

## Checklist rilis manual

- Pastikan application ID/bundle ID `id.podokoyo.tanidesa`, nama penerbit, kepemilikan brand dan domain final benar sebelum upload pertama.
- Siapkan backend production: HTTPS valid, APP_URL yang benar, database/migration/runtime permissions, provider, worker reset/pengingat, rate limits, backup/restore, dan log yang telah direduksi.
- Uji akun Owner/Admin, invalid login, expiry, perubahan role/transfer lintas web-mobile, undangan/reset dan logout pada staging.
- Uji galeri, batas file, upload asli, PDF/share pada Android/iOS, text scaling, keyboard, rotasi, tablet dan koneksi terputus.
- Lengkapi Data Safety/privacy labels, kebijakan privasi dan proses data/account lifecycle yang benar; sediakan akun reviewer melalui jalur yang aman.
- Tinjau manifest/perizinan/dependencies final dan kebijakan target API yang berlaku ketika mengirim aplikasi.
- Android: gunakan upload keystore milik penerbit dan Play App Signing; isi empat environment signing yang didokumentasikan. Release tidak memakai debug key.
- Build AAB release dengan API_BASE_URL HTTPS; simpan simbol obfuscation secara privat. Naikkan version/build number untuk rilis selanjutnya.
- iOS: gunakan macOS/Xcode, team/provisioning/certificate, entitlement Keychain, archive dan TestFlight; uji pada iPhone/iPad sebelum submission.
- Konfigurasikan App Links/Universal Links dan asosiasi domain bila ingin email membuka native langsung. Fallback tempel tautan lengkap sudah tersedia.
- Sediakan screenshot/deskripsi store dari aplikasi dan data uji yang sah, bukan data pribadi/keuangan production.

Tidak ada deployment, upload store, pembuatan akun store, penerbitan kebijakan, signing production atau klaim persetujuan store yang dilakukan dalam pekerjaan ini.
