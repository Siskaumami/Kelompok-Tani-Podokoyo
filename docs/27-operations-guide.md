# Panduan operasional

1. **Lengkapi kelompok:** Owner mengatur nama, zona waktu bisnis, harga/HPP Grade A per kg dan pengingat. Pengguna yang memerlukan akses diundang sebagai Admin melalui email.
2. **Isi data master nyata:** tambah anggota tani dan produk yang benar-benar dibuat. Untuk produk, isi gram kentang per unit, biaya bahan, kemasan, produksi, lain-lain dan harga jual. Simpan draf bila belum ingin ditampilkan di website.
3. **Catat panen:** pilih tanggal/petani, total berat, Grade A, Grade B dan afkir. Draf boleh belum selesai disortir. Periksa sisa belum diklasifikasikan; setelah nol, finalisasi. Stok bertambah otomatis hanya pada tahap final.
4. **Atur produksi:** rencana mengalokasikan Grade B untuk produk tertentu tanpa mengurangi stok. Saat proses benar-benar selesai, catat jumlah bahan yang benar-benar dipakai dan unit yang benar-benar dihasilkan. Teori dan pemakaian boleh berbeda. Rencana yang tidak lagi tertutup stok ditandai Perlu ditinjau.
5. **Catat penjualan:** pilih kanal, tanggal, barang dan jumlah. Grade A dimasukkan dalam kg; produk jadi dalam unit. Harga kosong mengikuti harga saat pencatatan; isi harga nyata jika kesepakatannya berbeda. Masukkan diskon dan biaya marketplace secara terpisah. Tidak perlu memasukkan transaksi itu lagi di pembukuan.
6. **Konfirmasi harian:** pilih Selesai mencatat atau Tidak ada penjualan. Ini menghentikan pengingat hari itu; bukan penutupan buku. Transaksi tambahan tetap boleh dicatat.
7. **Cek stok fisik:** mulai pemeriksaan, hitung barang, isi jumlah fisik/alasan/keterangan, lalu selesaikan. Bila stok berubah saat menghitung, perbarui stok sistem dan hitung ulang. Jangan menyalin angka lama ke baseline baru tanpa pemeriksaan.
8. **Periksa pembukuan:** pilih hari, bulan, tahun atau rentang tanggal. Telusuri transaksi pendukung dan unduh PDF. Pembatalan mengoreksi tanggal transaksi asal. Laporan ini menampilkan estimasi laba kotor, bukan laba bersih seluruh usaha.
9. **Terbitkan website:** lengkapi profil desa, profil anggota dan produk, unggah gambar nyata, isi tautan pembelian, lalu pilih Terbit. Hanya informasi terbit yang terlihat publik. Arsipkan master yang tidak digunakan; riwayat tidak dihapus.

## Angka dan koneksi

Kolom kg menerima koma desimal, maksimal tiga digit. Tulis seribu kg sebagai `1000`, bukan `1.000`; titik ditolak agar tidak terbaca sebagai satu kg. Kolom Rupiah/unit memakai bilangan bulat tanpa pemisah ribuan. Tampilan catatan akan memakai format Indonesia otomatis.

Semua transaksi memerlukan koneksi. Bila offline sebelum dikirim, aplikasi menyatakan data belum dikirim. Bila respons server hilang, status simpan belum pasti: jangan membuat transaksi baru dengan isi sama. Gunakan Periksa dengan kirim ulang pada formulir yang sama atau tutup dan periksa catatan server. Pengulangan memakai kunci yang sama tidak menggandakan transaksi.

## Koreksi

Transaksi final tidak diedit diam-diam. Batalkan dengan alasan, lalu catat pengganti. Pembatalan panen/produksi dapat ditolak jika barangnya sudah dipakai/dijual sehingga pembalikan akan membuat stok minus. Periksa kejadian sesungguhnya; jangan memalsukan jumlah agar sistem menerima.

Stock opname mengoreksi jumlah, bukan otomatis mencatat pendapatan/biaya. Jika selisih ternyata penjualan yang belum dicatat, koordinasikan pencatatan penjualan dan koreksi penyesuaian agar stok tidak berkurang dua kali. Aktivitas penting tersedia pada Riwayat aktivitas.
