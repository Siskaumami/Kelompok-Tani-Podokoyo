# Batas backend yang terkonfirmasi

Sumber: `apps/server/src/app.ts`, shared schemas, dan service domain pada ZIP yang diberikan. Tidak ada perubahan backend yang dilakukan.

| Area | Fakta kode | Dampak pada native |
| --- | --- | --- |
| Authentication | Cookie opaque + Origin persis APP_URL + CSRF; tidak ada endpoint JWT/mobile token | Dio memakai kontrak yang sama, secure storage dan header yang tepat. Origin berbeda harus diisi lewat APP_ORIGIN. |
| Session | Umur maksimum 12 jam, idle 2 jam, role/active live | Tidak ada refresh token yang bisa dipakai untuk memperpanjang sesi secara offline. Login ulang ketika server mencabut sesi. |
| Native push | Hanya Web Push subscription endpoint/keys VAPID. Tidak ada device-token FCM/APNs. | Tidak mendaftarkan token native palsu, tidak memasang Firebase. `/notifications` dan konfirmasi harian tetap bekerja saat aplikasi dibuka. |
| Email | Undangan memakai provider Brevo, reset memakai queue/worker, email pengingat opsional | Mobile menampilkan hasil/error server. Queue accepted tidak disebut email sudah diterima. Tidak membuat tautan undangan/reset sendiri. |
| Links | Email memakai HTTPS APP_URL dan token fragment | Dapat menempel tautan lengkap dalam native. Verifikasi App Links/Universal Links memerlukan domain final dan konfigurasi asosiasi pada hosting/penerbit, yang tidak ada dalam berkas yang diberikan. |
| Images | Multipart tunggal 5 MiB JPEG/PNG/WebP; image private diarahkan ke signed Filebase URL | Galeri dan unggahan API native tersedia. Perubahan storage/provider harus mengikuti kontrak server; tidak ada secret storage di klien. Signed URL yang sudah diterbitkan dapat tetap berlaku 5 menit. |
| Marketplace | Link eksternal dan input manual OFFLINE/WHATSAPP/SHOPEE/TOKOPEDIA | Tidak ada import/sinkronisasi pesanan atau pembayaran otomatis. |
| Inventory | Semua perubahan berasal event domain; tidak ada API ubah balance langsung | Native tidak menulis angka stok langsung. Planning tidak mengonsumsi stok. Stale opname harus refresh/recount eksplisit. |
| Reports | Satu calculation service; rentang maksimum 367 hari inklusif, maksimum 5.000 transaksi; PDF maksimal 5.000 detail lines | Membaca angka/PDF server. Rentang besar ditangani dengan pesan server dan periode lebih pendek. Bukan general ledger, FIFO, atau laba bersih usaha. |
| Reversals | Void penuh dengan reversal dan alasan; tidak ada partial refund/return | Native memakai endpoint void yang ada. Tidak mengedit histori atau menambah retur parsial lokal. |
| Users/data deletion | API menyediakan status aktif/nonaktif Admin, arsip master dan audit; tidak ada endpoint penghapusan akun/data pribadi | Tidak berpura-pura menghapus akun lewat tombol nonaktifkan. Penerbit perlu menilai kebijakan store dan menyiapkan proses data/retensi/penghapusan yang benar sebelum distribusi. |
| Public data | Website publik hanya DTO published; HPP/stok/audit tetap private | `Lihat website` membuka browser eksternal. Flutter tidak meneruskan cookie atau data ERP ke halaman publik. |

Pengingat native latar belakang dan pemrosesan transaksi offline tidak dijanjikan. Tidak ada workaround yang mengganti otoritas server. Ketergantungan konfigurasi layanan nyata dan worker perlu diuji pada staging; tidak ada kredensial atau URL deployment nyata yang diberikan pada tugas ini.
