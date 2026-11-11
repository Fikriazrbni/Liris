# Liris

Untuk **Windows 11 x64**, unduh [Liris Windows Preview v0.1.0](https://github.com/Fikriazrbni/Liris/releases/tag/windows-v0.1.0) dan pilih `Liris-Setup-Windows-x64.exe` di bagian **Assets**. Petunjuk instalasi dan pengembangan ada di [windows/README.md](windows/README.md).

## Liris for macOS

Aplikasi desktop native untuk menampilkan lirik tersinkron dari musik yang diputar di **YouTube Music**, dengan dukungan Spotify dan Apple Music desktop. Dibuat dengan SwiftUI + AppKit, tanpa Electron, server lokal, npm, atau API key.

Terinspirasi alur penggunaan [FrontLine Lyrics Desktop](https://github.com/juliocax/FrontLine-Lyrics-Desktop). Implementasi Swift ini ditulis baru; tidak menyalin kode, aset, atau backend proyek referensi.

## Download aplikasi siap pakai

Unduh [Liris v0.4.3 untuk Apple Silicon](https://github.com/Fikriazrbni/Liris/releases/tag/v0.4.3), ekstrak ZIP, lalu pindahkan **Liris.app** ke **Applications** dan buka. Tidak perlu Swift, Python, uv, atau build manual. Runtime Python dan ShazamIO sudah dibundel. Repo dan release tersedia public.

Build awal ini ditandatangani ad hoc, belum Developer ID/notarized; macOS dapat menolak pembukaan unduhan. Ini pre-release untuk pengujian, bukan paket dengan verifikasi distribusi Apple. Minimum macOS 14, Apple Silicon (M1 atau lebih baru); Intel belum tersedia.

Untuk YouTube/YouTube Music: Panduan koneksi → **Buka extension dan Brave** mendaftarkan native host dari lokasi app yang terpasang dan membuka folder extension. Load unpacked di Brave masih perlu dilakukan sekali oleh pengguna. Untuk Discord: Auto → Hubungkan → **Aktifkan audio** secara manual. Izin capture macOS dan internet tetap diperlukan. Memindahkan app setelah setup extension memerlukan klik setup lagi agar path native host diperbarui.

## Install melalui Homebrew

```sh
brew install --cask fikriazrbni/tap/liris
```

Tap: [Fikriazrbni/homebrew-tap](https://github.com/Fikriazrbni/homebrew-tap). Khusus Apple Silicon, macOS 14+. Homebrew mengunduh app yang sudah dibangun dan memverifikasi checksum; build ini masih pre-release dan belum notarized Apple. Setup extension Brave dan izin audio tetap diperlukan sesuai fitur yang dipakai.

## Jalankan di MacBook

Persyaratan: **macOS 14 Sonoma atau lebih baru**, Command Line Tools untuk membangun. Build menghasilkan aplikasi untuk arsitektur Mac yang dipakai (Apple Silicon pada mesin ini).

Tes memakai Swift Testing dan membutuhkan toolchain Swift 6 atau lebih baru. Browser bawaan untuk koneksi pertama adalah Brave; kamu bisa menggantinya dari pemilih browser di aplikasi.

```bash
./scripts/setup-shazamio.sh
./scripts/build-app.sh
./scripts/run.sh
```

Setelah dibangun, cukup buka **dist/Liris.app** dari Finder. Tidak ada server yang perlu dijalankan. Build ditandatangani ad hoc untuk penggunaan lokal, belum memiliki Developer ID/notarization untuk distribusi publik. Simpan aplikasi pada lokasi tetap agar izin Automation lebih konsisten.

Untuk melihat tampilan dengan teks orisinal tanpa memutar atau merekam audio:

```bash
./scripts/run.sh --demo
```

Jika aplikasi sudah terbuka, gunakan tombol **Coba demo** atau **Jalankan demo visual** di aplikasi. macOS tidak meneruskan argumen peluncuran ke instance yang sudah terbuka.

## Hubungkan YouTube Music

1. Buka `music.youtube.com` di **Google Chrome, Brave, Edge, atau Safari**. Putar satu lagu. Gunakan satu tab pemutar agar tidak ambigu.
2. Chrome / Brave / Edge: aktifkan **View → Developer → Allow JavaScript from Apple Events**. [Panduan resmi Chromium](https://www.chromium.org/developers/applescript/).
3. Safari: aktifkan fitur developer di **Settings → Advanced → Show features for web developers**, lalu **Settings → Developer → Automation → Allow JavaScript from Apple Events**. Versi Safari lama menaruh opsi ini di menu Develop. [Panduan resmi Apple](https://developer.apple.com/documentation/safari-developer-tools/developer-settings).
4. Di Liris, pilih **YouTube Music** dan browser yang dipakai, lalu klik **Hubungkan**.
5. Pilih **Allow** saat macOS meminta izin Automation. Jika ditolak sebelumnya, periksa **System Settings → Privacy & Security → Automation → Liris**, lalu hubungkan ulang.

Pengaturan izin di atas dilakukan pengguna sendiri. Liris tidak mengubah pengaturan browser. Integrasi tidak memakai mikrofon atau merekam audio/layar. Firefox, browser selain yang tercantum, serta pembungkus YouTube Music pihak ketiga belum didukung.

## Fitur

### Pemeriksaan otomatis (0.2.0)

Liris memantau waktu media, progress bar, teks waktu, dan status MediaSession. Sumber yang tidak sejalan atau macet dapat diganti otomatis. Jika tidak ada sumber yang dapat dipercaya, lirik ditahan sampai pemutar pulih. Peralihan kembali ke jam media memerlukan beberapa pembacaan yang cocok agar tidak bolak-balik pada batas detik.

Versi lirik diperiksa pada hasil API exact, pencarian, serta cache: judul, artis, penanda live/remix/akustik, durasi, isi timestamp, dan batas akhir lagu. Kandidat yang tidak cocok dilewati otomatis. Untuk lagu baru, aplikasi membandingkan kandidat LRCLIB dan mengutamakan album yang cocok. Perbedaan timing pada baris unik yang sama ditandai sebagai ketidakpastian; salinan timestamp yang identik tidak dihitung sebagai bukti tambahan.

Panel status menjelaskan hasilnya. Menu **Versi lain** menampilkan album, durasi, dan waktu awal lirik; pilihan yang lolos pemeriksaan struktural disimpan untuk lagu itu. Offset nonnol juga disimpan per kombinasi judul/artis/album/durasi. **Gunakan pilihan otomatis** menghapus pilihan versi dan koreksi tersimpan; **Periksa ulang** mengambil data baru dan membandingkannya kembali. Impor/pilihan manual yang tidak cocok tetap diberi peringatan dan tidak disimpan sebagai pilihan otomatis yang aman.

Perbandingan versi disimpan hingga tujuh hari untuk mengurangi permintaan jaringan. Cache lama tetap dapat dipakai saat offline, dengan status belum dibandingkan jika arsip pemeriksaannya belum ada. Internet lambat/rate limit tidak menyebabkan pencarian berulang pada setiap tick pemutar.

**Batas deteksi:** metadata dan timestamp yang masuk akal belum membuktikan kecocokan dengan vokal. Jika semua kandidat memiliki kesalahan sama, atau tidak ada cukup baris unik yang bisa dibandingkan, salah timing dapat lolos. Liris tidak mendengar audio dan tidak menggeser timestamp berdasarkan tebakan; pemeriksaan ini mengurangi masalah berulang, bukan menjamin sinkronisasi vokal 100%.

- Membaca judul, artis, durasi, dan posisi aktual lagu setiap sekitar satu detik. Memprioritaskan tab YouTube Music yang sedang bermain.
- Interpolasi waktu memakai jam monotonic untuk lirik yang halus. Pause, seek, dan pergantian lagu mengatur ulang acuan waktu.
- Lirik bertimestamp dari [LRCLIB](https://lrclib.net/docs), cache di disk, serta fallback pencarian dengan pemeriksaan judul/artis/durasi.
- Overlay di atas aplikasi lain, dapat dipindah dan diubah ukurannya. Mode kunci meneruskan klik ke aplikasi di bawahnya; buka kunci lewat menu bar Liris atau halaman Tampilan.
- Warna Lime/Lavender/Peach, ukuran dan opasitas overlay, pengaturan waktu ±10 detik (langkah 0,2 detik).
- Pencarian manual, pilihan versi lirik, impor LRC UTF-8. Lirik biasa tanpa timestamp tetap dibaca, tidak diberi timing buatan.
- Kontrol play/pause, seek, klik baris lirik untuk melompat ke waktunya.
- Jika tidak terhubung ke pemutar, tombol play hanya menjalankan **timer manual**; mulai bersamaan dengan musikmu.
- Spotify dan Apple Music desktop melalui Automation; tidak membutuhkan Spotify Premium atau kredensial API.
- Menu bar untuk membuka aplikasi, overlay, mengunci/membuka kunci, dan keluar.

| Pintasan saat aplikasi aktif | Tindakan |
| --- | --- |
| ⌘F | Cari lirik |
| ⌘O | Impor LRC |
| ⇧⌘L | Tampilkan/sembunyikan overlay |
| ⌥⌘→ / ⌥⌘← | Majukan/mundurkan lirik 0,2 detik |

## Batasan versi awal

Liris membaca pemutar yang didukung, **belum mengenali lagu dari sembarang audio sistem seperti Shazam**. YouTube Music dapat mengubah struktur DOM; adapter browser mungkin perlu diperbarui. Hasil bergantung pada ketersediaan serta ketepatan lirik LRCLIB, dan versi video/live/remix bisa berbeda dari rekaman studio. Jika pencocokan otomatis tidak tepat, pilih hasil pencarian atau impor LRC dan atur sinkronisasi. Liris tidak memutar musik sendiri, menerjemahkan, atau melakukan romanisasi.

Lirik baru memerlukan internet; lirik yang berhasil ditemukan otomatis dapat dibaca dari cache saat offline. Rate limit/`Retry-After`, respons HTML, dan galat jaringan ditangani tanpa retry berulang. Ad detection berbasis halaman YouTube Music bersifat best effort.

## Data dan privasi

- Browser yang dipilih dibaca melalui Apple Events, hanya untuk menemukan tab beralamat `https://music.youtube.com/` dan mengambil metadata/waktu di tab tersebut.
- Judul, artis, album (jika ada), dan durasi dikirim ke LRCLIB untuk pencarian lirik. Pencarian manual mengirim teks pencariannya.
- Sampul Spotify/YouTube Music diunduh dari URL HTTPS yang disediakan pemutar.
- Lirik disimpan di `~/Library/Caches/id.local.liris/lyrics`. Pengaturan tampilan ada di UserDefaults dengan domain `id.local.liris`.
- Arsip perbandingan dan pilihan versi disimpan di folder cache yang sama. Offset per lagu disimpan dalam `trackOffsets` di UserDefaults. Data ini tetap lokal; pilihan/koreksi pengguna tidak dikirim ke LRCLIB.
- Tidak ada telemetry, akun aplikasi, upload audio, atau service backend.

## Pengembangan dan verifikasi

```bash
./scripts/test.sh
node --test scripts/browser-probe.test.cjs   # opsional; membutuhkan Node.js
./scripts/build-app.sh debug
./dist/Liris.app/Contents/MacOS/Liris --verify-bundle
```

`--verify-bundle` memeriksa resource serta mengompilasi AppleScript untuk aplikasi yang terpasang. Pemeriksaan ini tidak mengeksekusi Apple Events, meminta izin, atau mengubah pemutaran. Tes otomatis mencakup parsing LRC, offset, seek mundur, matching lagu, cache offline, URL encoding, rate limit, respons non-JSON, dan kontrak snapshot JavaScript pada fixture. Tes tersebut tidak menggantikan pengujian pada tab YouTube Music nyata setelah izin pengguna aktif.

Untuk diagnosis lokal metadata dan waktu pemutar tanpa mengambil lirik atau mengubah playback, jalankan `./dist/Liris.app/Contents/MacOS/Liris --diagnose-player`. Perintah ini membaca tab YouTube Music di browser terpilih dan mencetak judul, artis, posisi, durasi, serta status pemutaran.

Tambahkan `--watch` untuk memantau 12 sampel lokal dan melihat keputusan monitor sumber waktu. Ini tidak mengambil lirik atau mengubah playback.

Versi 0.1.1 memakai durasi dari progress bar YouTube Music karena durasi MediaSource dapat terus bertambah saat buffering. Lirik dengan timestamp isi yang melebihi durasi lagu lebih dari tiga detik ditolak pada hasil API maupun cache; pencarian lalu mencoba versi lain dengan judul, artis, dan durasi yang sesuai. File LRC yang diimpor manual tetap bisa dipilih pengguna.

Versi 0.1.2 membandingkan posisi media dengan posisi progress bar. Jika selisihnya lebih dari 1,25 detik, atau elemen media menunjukkan berhenti ketika MediaSession aktif, Liris mengikuti progress bar dan status MediaSession. Waktu media yang cocok tetap dipakai untuk ketelitian pecahan detik. Saat mengikuti progress bar, pembacaan dilakukan lebih sering; jam monotonic tidak direset untuk setiap pembacaan detik yang sama dan tidak maju melewati detik berikutnya sebelum pemutar mengonfirmasinya. Kontrol play/pause memakai tombol pemutar YouTube Music. Saat elemen media tidak sejalan, seek dari Liris dinonaktifkan: lakukan perpindahan posisi langsung di YouTube Music.

Struktur kode dan keputusan teknis tersedia di [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).


## Auto gabungan (0.3.0)

Mode **Auto** menerima metadata YouTube/YouTube Music lewat extension Brave tanpa Allow JavaScript from Apple Events. Mode **YouTube Music** lama tetap tersedia. Native host lokal dibundel bersama app; daftar host dipasang melalui `python3 scripts/install-auto-bridge.py`, lalu extension perlu dimuat pengguna sekali melalui Load unpacked. Panduan lengkap: [docs/AUTO-SETUP.md](docs/AUTO-SETUP.md).

Mesin pengenalan audio sistem ScreenCaptureKit + ShazamKit juga disertakan, tetapi **Discord belum aktif pada build ad hoc**: layanan ShazamKit pada App ID, provisioning dan signing harus tersedia terlebih dahulu. Flag build lokal tetap false sehingga tidak memulai capture yang belum bisa berfungsi. Tombol aktivasi terpisah memerlukan persetujuan izin sistem setelah konfigurasi tersedia.


## Backend ShazamIO (0.4.0)

Jalur Discord/audio sistem kini memakai ShazamIO 0.9.0, menggantikan ShazamKit yang disebut pada catatan versi 0.3.0. Tidak perlu akun Apple Developer. Runtime Python lokal telah dipasang; panduan aktivasi dan batas pengujian ada di [docs/AUTO-SETUP.md](docs/AUTO-SETUP.md). Extension YouTube/YouTube Music tetap diprioritaskan; worker pengenalan audio ditahan selama tab extension bermain. Cuplikan 12 detik hanya berada di memori dan diproses melalui layanan online Shazam, dengan waktu awal cuplikan untuk kompensasi latensi. Aktifkan lewat Panduan koneksi setelah memilih Auto → Hubungkan.


## Kontrol audio manual (0.4.2)

Audio sistem selalu diaktifkan manual lewat **Aktifkan audio**; membuka app, Hubungkan, dan reconnect tidak memulai capture. Panel status permanen menunjukkan keadaan capture dan menyediakan **Matikan audio**. Kontrol yang sama tersedia di menu bar, panduan, dan overlay yang tidak terkunci; overlay terkunci tetap menampilkan indikator aktif. Preferensi aktivasi otomatis versi lama dan flag `--resume-auto-audio` sudah dihentikan.

Mic tidak dibuka. Output percakapan Discord dan suara mic yang diputar kembali dapat ikut masuk cuplikan; matikan pengenalan selama mengobrol. Campuran suara dapat mengurangi ketepatan pengenalan lagu.
