Saya ingin merapikan UI Liris Windows yang sudah berjalan dan sedang dites. Tolong langsung implementasikan revisi visual, tanpa merombak logic audio, sinkronisasi, extension, atau format data yang sudah berfungsi.

## Referensi wajib

Repo produk: https://github.com/Fikriazrbni/Liris
Paket referensi Mac: https://github.com/Fikriazrbni/Liris/tree/codex/macos-ui-reference/docs/ui-reference/macos-v0.4.3

Buka dan lihat PNG-nya, jangan hanya membaca nama berkas:
- 01-main-audio-off.png: acuan utama layout, warna, hierarki, dan komponen.
- 02-main-audio-active.png: banner privasi jingga dan tombol Matikan audio.
- 03-sync-uncertain.png: pemberitahuan timing, Versi lain, dan Periksa ulang.
- 04-appearance.png: pengaturan tema dan pratinjau overlay.
- 05-connection-guide.png: tata letak panduan dan kartu instruksi. Konten ini khusus Mac; adaptasikan instruksi Windows.
- 06-overlay-audio-active.png: overlay ringkas dengan status audio dan tombol Matikan yang selalu terlihat saat tidak terkunci.
- 07-empty.png: empty state tanpa lagu.

Gambar ini render native SwiftUI dari Liris Mac v0.4.3 dengan data demo orisinal. Status audio aktif hanya simulasi. Screenshot utama 2440×1580 adalah render @2x dari viewport 1220×790 logical points; JANGAN membuat layout Windows selebar 2440 DIP. Overlay 1600×360 mewakili 800×180 logical points. Beberapa area adalah scroll view; yang terlihat bukan seluruh isi halaman.

## Arah visual

Buat Liris Windows terasa seperti produk yang sama: tenang, ringan, rapi, dengan lirik sebagai fokus. Hindari tampilan form utilitas yang penuh kotak, tombol besar seragam, garis tebal, atau kontrol default yang tidak selaras. Jangan mengganti stack aplikasi hanya untuk menata UI; gunakan styles/templates/components yang tersedia di stack Windows saat ini.

Gunakan token terpusat, mendekati implementasi Mac:
- Background #0E1011, sidebar #131516, card #1A1D1D.
- Accent lime #C9F07A, lavender #BAA6FF, peach #FFB887.
- Muted text #8C9691; primary text off-white; border putih sekitar 7% opacity.
- Jingga hanya untuk status audio/peringatan, bukan semua tombol.
- Radius kartu 13–17 DIP; tombol 8–9 DIP; pemisah tipis 1 DIP.
- Sidebar sekitar 205 DIP; panel kanan sekitar 252 DIP pada viewport 1220 DIP.
- Padding konten sekitar 26–30 DIP; gap utama 24 DIP; padding kartu 17–20 DIP. Gunakan grid spacing 4/8 DIP untuk detail.

## Struktur tampilan utama

1. Sidebar: logo lime + waveform gelap, nama liris, tagline kecil, navigasi dengan ikon konsisten. Nav aktif memakai latar lime transparan dan teks lime; menu bantuan di bagian bawah.
2. Header: eyebrow kecil, judul 22–25 DIP medium/semibold, tombol overlay di kanan.
3. Panel status audio tepat di bawah header, terlihat di semua halaman. Off: netral dan penjelasan aktivasi manual. Active: jingga, teks eksplisit bahwa pengenalan aktif, informasi signature Shazam, dan tombol Matikan audio. Bedakan starting/stopping/suppressed sesuai state aplikasi nyata.
4. Konten dua kolom: kiri fleksibel berisi sumber, status sync jika diperlukan, kartu lagu, panggung lirik, dan kontrol playback; kanan untuk warna, ukuran, opasitas, offset, dan akses overlay.
5. Kartu lagu: sampul persegi membulat sekitar 106 DIP, metadata dengan hierarki judul/artis/album. Gunakan placeholder sederhana ketika artwork tidak ada.
6. Lirik: baris aktif besar, semibold, lime; baris sekitar lebih redup tetapi masih terbaca. Jaga ruang kosong dan pemusatan. Auto-scroll halus hanya saat baris aktif berubah, bukan pada setiap tick. Hormati reduced motion. Judul lagu/teks panjang harus wrap atau truncate dengan sengaja, tidak memaksa layout melebar.
7. Playback: slider tipis, label waktu, tombol play utama berbentuk lingkaran lime, kontrol sekunder ringan. Footer status kecil tidak bersaing dengan lirik.
8. Panel pengaturan dan halaman panjang dapat discroll secara independen. Jangan sampai header, banner audio, atau kontrol playback terpotong ketika jendela diperkecil.

## Tipografi dan komponen Windows

Gunakan Segoe UI Variable/Segoe UI atau font sistem Windows yang tersedia. Jangan membundel font SF milik Apple. Sasaran: judul lagu 24–26 DIP, heading 22–25, body 12–14, label 10–12, lirik utama sekitar 28–34; sesuaikan keterbacaan Windows. Serif hanya untuk heading editorial/empty state bila cocok, jangan untuk semua kontrol.

Tata button, combo box, slider, toggle, scrollbar, menu, dialog pencarian dan impor agar selaras. Primary button lime dengan teks gelap; secondary button gelap dengan border halus. Sediakan hover, pressed, disabled dan keyboard focus yang jelas. Jangan menghilangkan focus ring. Kontras dan Windows High Contrast lebih penting daripada meniru teks Mac yang terlalu redup.

Overlay: rounded dark translucent background, tipografi besar, satu baris berikutnya, judul kecil. Status audio aktif harus tetap terlihat saat overlay dikunci; Matikan harus mudah dijangkau dari overlay yang tidak terkunci dan system tray. Gunakan perilaku jendela Windows yang benar untuk drag, always-on-top, click-through dan DPI, tanpa menyalin traffic-light/titlebar macOS.

## Batas perubahan

- Lanjutkan pada branch Windows yang sedang dikerjakan; jangan reset atau membuang perubahan/test lokal.
- Jangan mengubah source/build/release macOS atau tap Homebrew.
- Jangan mengubah perilaku source selection, LRCLIB, cache, offset, pemilihan versi, clock, atau protokol native messaging demi screenshot.
- Audio tetap off pada startup/Connect/reconnect, manual start saja. Jangan menambahkan auto-start, menyalakan mikrofon, atau mengirim audio untuk menguji UI.
- State demo harus jelas terpisah dari state produksi. Jangan menampilkan badge SYNCED/connected/audio aktif secara hardcoded.
- Untuk screenshot, gunakan data demo orisinal; jangan mengambil audio atau informasi akun pengguna.

## Cara kerja dan kriteria selesai

Periksa UI Windows saat ini dan bandingkan dengan gambar acuan. Identifikasi perbedaan yang paling memengaruhi hierarki, proporsi, warna, dan keterbacaan, lalu implementasikan perbaikannya. Gunakan satu sumber token/style agar konsisten lintas halaman.

Verifikasi aplikasi yang benar-benar dirender, bukan hanya kompilasi: utama audio off/on (simulasi), sync uncertain, kosong/loading/error, pengaturan, panduan, pencarian dan overlay. Cek 1220×790 serta viewport kecil; uji Windows scaling 100%, 125%, 150%, 200% sesuai perangkat yang tersedia. Tidak boleh ada teks/tombol bertumpuk, clip, atau kontrol utama hilang. Pastikan tab navigation/focus, resize, hover dan disabled state bekerja.

Jalankan tes regresi relevan setelah perubahan UI. Laporkan file yang diubah, hasil pengujian, dan bagian yang belum diuji. Sertakan screenshot before/after dari aplikasi Windows nyata. Jangan mengklaim sama dengan Mac hanya karena build berhasil. Lanjutkan sampai hasilnya rapi dan bisa saya coba, bukan berhenti pada proposal desain.
