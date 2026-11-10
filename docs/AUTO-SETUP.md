# Mode Auto 0.4.2

## YouTube dan YouTube Music di Brave

1. Native host dipasang dengan `python3 scripts/install-auto-bridge.py` setelah build. Installer hanya mendaftarkan host Liris, tidak mengubah JavaScript, preferensi, atau extension browser lain.
2. Buka Liris → Panduan koneksi → Buka extension dan Brave.
3. Di `brave://extensions`, aktifkan Developer mode → Load unpacked → pilih folder AutoExtension yang dibuka. Ini izin instalasi extension, bukan Allow JavaScript from Apple Events.
4. Reload tab YouTube / YouTube Music, pilih sumber **Auto**, lalu Hubungkan.

Extension tetap berjalan tanpa Liris; metadata terkini disimpan oleh native host pada `~/Library/Application Support/Liris/Bridge`. Hanya domain YouTube yang diizinkan. Tidak ada server HTTP lokal, port jaringan, rekaman audio, cookie, atau riwayat penjelajahan yang dikirim. Metadata heartbeat kedaluwarsa setelah tiga detik. Tab playing diprioritaskan; jika beberapa tab playing, sumber sebelumnya dipertahankan. Artist/channel YouTube tidak selalu nama artis rekaman, sehingga beberapa video perlu pencarian lirik manual.

Play/pause diteruskan ke tombol pemutar pada tab terpilih. Seek dinonaktifkan bila video node tidak sejalan dengan progress bar. Sumber YouTube Music lama lewat Apple Events tetap tersedia dan tidak diaktifkan otomatis oleh mode Auto.

## Discord / audio sistem — ShazamIO

Runtime ShazamIO 0.9.0 dan Python 3.12 sudah dipasang lokal oleh setup. Tidak memerlukan App ID, provisioning profile, API key, atau akun Apple Developer. Pilih Auto → Hubungkan, lalu tekan **Aktifkan audio** pada panel status di bagian atas jendela. Izinkan Screen & System Audio Recording saat macOS meminta. Audio selalu mati saat app dibuka dan tidak menyala saat Hubungkan/reconnect; pilihan aktif versi lama dihapus. Setiap sesi perlu aktivasi manual. **Matikan audio** tersedia di panel status utama, menu bar Liris, panduan, dan overlay yang tidak terkunci. Putuskan juga menghentikan capture dan worker. Jika overlay terkunci, gunakan menu bar Liris untuk mematikan audio.

Cuplikan 12 detik mono PCM16 44100 Hz disimpan hanya di RAM dan dikirim lewat stdin ke worker Python. ShazamIO memprosesnya untuk pencocokan melalui layanan online Shazam. Semua output sistem, termasuk percakapan Discord, dapat masuk cuplikan; mikrofon tidak dibuka. Tidak ada file WAV atau rekaman permanen. Saat extension melaporkan YouTube/YouTube Music bermain, worker dibatalkan dan buffer dikosongkan; audio fallback kembali mengumpulkan cuplikan setelah jalur extension tidak aktif.

Posisi lagu dihitung dari offset hasil pengenalan + selisih jam monotonic sejak awal cuplikan, bukan sejak jawaban jaringan diterima. Silence gate, expiry hasil, satu worker aktif, timeout, cooldown, dan token pembatalan mencegah retry bertumpuk atau hasil lama menggantikan sesi baru. Musik dipause/seek lewat aplikasi sumber ketika menggunakan pengenalan audio. Versi live, cover, campuran percakapan, pergantian lagu dan perubahan kecepatan tetap bisa menyebabkan no-match atau ketidakpastian.

Runtime berada di `.runtime/shazamio` dan `.runtime/python` di folder proyek, diabaikan Git. App menyimpan path absolut runtime lokal; jangan hapus/pindahkan folder runtime selama app digunakan. Untuk membuat ulang: `./scripts/setup-shazamio.sh` lalu `./scripts/build-app.sh`. Dependensi dipin dalam backend/requirements.lock. Distribusi app mandiri ke Mac lain memerlukan pengemasan runtime tersendiri.

ShazamIO adalah integrasi API tidak resmi yang dapat berubah. Jalur extension tetap menjadi prioritas untuk posisi pemutaran yang dapat dibaca langsung.

## Status pengujian

Build dan tes unit/protokol dapat diverifikasi otomatis. Pemasangan extension memerlukan Load unpacked dari pengguna. Pengenalan audio nyata memerlukan izin capture macOS dan audio yang dapat dikenali. Tes unit/import/format worker tidak membuktikan pengenalan suatu lagu nyata.


## Diagnosis audio 0.4.1

Status aplikasi kini menunjukkan apakah capture belum aktif, audio belum masuk, hening, cuplikan sedang dikumpulkan, worker sedang mengenali, no-match, atau error. Error aktivasi disimpan sampai ditangani, bukan hanya pesan yang hilang pada polling berikutnya. Mulai 0.4.2 pengenalan audio tidak diingat untuk koneksi berikutnya. Putuskan menghentikan capture; Hubungkan selalu membiarkan audio mati sampai diaktifkan manual.

Jeda audio singkat tidak lagi langsung menghapus lagu dan membatalkan pencarian lirik: identitas dipertahankan selama TTL hasil, dengan posisi dijeda saat tidak ada suara, lalu dibuang jika tidak diperbarui. Metrik diagnosis tanpa isi audio ditimpa pada `~/Library/Caches/id.local.liris/audio-status.json`, mencakup jumlah callback, level, buffer, worker, error dan status lirik. `--diagnose-audio` membaca file itu; periksa updatedAt untuk freshness.

`--probe-audio` melakukan uji capture lokal 15 detik tanpa worker/network; `--probe-recognition` melakukan uji pengenalan maksimal 35 detik dan mengirim signature audio ke Shazam, sehingga hanya jalankan dengan persetujuan terhadap audio yang diputar. `--resume-auto-audio` telah dihapus pada 0.4.2; argumen lama ini tidak dapat menyalakan capture saat app dibuka.


Jika status menunjukkan penolakan TCC, buka tombol **Buka izin Screen & System Audio Recording** di panduan, lalu izinkan Liris pada kategori tersebut. Jalur ScreenCaptureKit saat ini memakai filter display walaupun hanya mengonsumsi output audio. Izin Audio Recording saja dapat tidak cukup. Sesudah mengganti build yang ditandatangani ad hoc, macOS dapat meminta pemberian ulang izin; tutup dan buka kembali Liris setelah mengubahnya. Keberhasilan probe dari terminal/Codex tidak menjamin izin aplikasi yang dibuka normal sama.

Jika izin tetap ditolak sesudah toggle dan restart, hapus entri Liris lama dengan tombol minus di pengaturan tersebut, tambahkan kembali `dist/Liris.app` yang sedang dipakai dengan tombol plus, aktifkan, lalu buka ulang app. Langkah ini memperbarui entri yang mungkin masih menunjuk identitas tanda tangan build lama. Jangan membangun ulang app di antara pemberian izin dan pengujian ini.


## Indikator dan privasi audio 0.4.2

Panel selalu menunjukkan Mati, Mengaktifkan, Aktif, atau Menghentikan. Saat audio diaktifkan, indikator jingga muncul di jendela utama dan overlay, dan ikon menu bar berubah menjadi lingkaran rekam. Pengenalan yang ditahan karena extension bermain tetap ditandai aktif: capture masih berjalan, sedangkan worker Shazam dibatalkan dan buffer pengenalan dikosongkan. Tombol Matikan membuang buffer, membatalkan worker/start yang tertunda, lalu menghentikan stream. Hasil request lama tidak dapat mengaktifkan ulang sesi. Indikator menampilkan Menghentikan sampai stream selesai berhenti.

Liris hanya mengonsumsi output audio sistem. Pada macOS 15+ captureMicrophone ditetapkan false secara eksplisit; tidak ada output stream mikrofon, izin mikrofon, atau pembukaan input mic. Mic Discord yang aktif sendiri tidak otomatis masuk ke Liris. Suara peserta Discord lain merupakan output sistem dan dapat ikut dianalisis; suara sendiri juga dapat masuk jika diputar balik lewat monitoring, echo, atau loopback. Campuran percakapan dapat menyebabkan no-match, hasil keliru, atau posisi kurang tepat. Matikan pengenalan selama percakapan pribadi; untuk YouTube/YouTube Music gunakan jalur extension tanpa mengaktifkan audio.
