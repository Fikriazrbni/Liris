# Liris for Windows — development preview

Versi Windows berada di folder `windows/`. Kedua platform menggunakan extension
di `Extension/` dan backend pengenalan audio di `backend/`.

## Menjalankan paket

Untuk instalasi, jalankan `Liris-Setup-Windows-x64.exe`. Liris terpasang untuk
akun Windows saat ini tanpa hak administrator. Cari **Liris** di Start/Search
atau buka shortcut desktop jika opsi tersebut dicentang. Untuk menghapusnya,
buka **Settings → Apps → Installed apps → Liris → Uninstall**.

Untuk versi portable, ekstrak **seluruh** `Liris-Windows-x64-preview.zip` ke lokasi tetap, lalu buka
`Liris-Windows/Liris.exe`. Jangan pisahkan EXE dari `_internal/` dan dua executable
pendamping. Paket membawa Python, Qt, WASAPI/PortAudio, ShazamIO dan dependensinya;
pengguna akhir tidak perlu Python, pip, .NET SDK, atau build manual.

Target awal Windows 11 x64. Belum ditandatangani; belum diuji pada instalasi Windows
bersih, Windows 10, ARM64, remote desktop, atau perangkat audio lain. Ini preview
pengembangan, bukan klaim parity final atau release Windows publik.

1. Buka **Bantuan → Setup extension Windows** dari Liris. Ini hanya menulis
   manifest host Liris dan key HKCU NativeMessagingHosts untuk Chrome/Brave/Edge.
2. Buka halaman Extensions browser → Developer mode → Load unpacked → pilih folder
   `Extension` yang dibuka. Extension sama persis dengan extension Mac.
3. Reload YouTube/YouTube Music, lalu **Hubungkan**. Tidak memakai Apple Events,
   debugging port, cookie, atau izin JavaScript Apple Events.
4. Audio tetap **Mati**. Jalur extension tidak membutuhkan audio.
5. Untuk Discord/aplikasi lain, klik **Aktifkan audio…**, baca penjelasan privasi,
   lalu setujui secara manual. **Matikan audio** tersedia di jendela, overlay tidak
   terkunci, dan tray. Connect/reconnect/Putuskan selalu mematikan audio.

Jika beralih dari portable ke installer, atau folder paket dipindah, jalankan
Setup extension lagi agar path native host
diperbarui. Setup tidak menginstal extension secara diam-diam. Untuk menghapus
registrasi host, jalankan `unregister-bridge.ps1`, lalu hapus extension di browser.

Tutup jendela menyembunyikan aplikasi ke tray bila tray tersedia; gunakan **Keluar**
untuk menghentikan aplikasi. Klik ganda ikon tray untuk membuka jendela. Overlay
bisa diubah ukuran/dipindah lewat bingkai Windows, diatur warna/ukuran font/opasitas,
dan dikunci klik menembus. **Buka kunci overlay** selalu tersedia lewat tray.

## Lirik dan waktu

- Pencarian otomatis LRCLIB, pencarian manual, pilihan versi, dan impor LRC UTF-8.
- LRC multi timestamp, pecahan detik, offset header, baris kosong, dan teks biasa.
  Teks biasa tidak diberi timing buatan.
- Offset positif memajukan lirik; tersimpan per judul/artis/album/durasi.
- Cache kandidat tujuh hari, pilihan aman, fallback offline dengan validasi ulang.
  HTTP 429/503 menghormati Retry-After; tidak retry pada setiap tick.
- Versi otomatis memerlukan judul/artis cocok, durasi ±5 detik, dan timestamp tidak
  melewati akhir lagu lebih dari tiga detik. Live/remix tidak dihapus dari judul.
  Album diprioritaskan; konflik timing empat baris unik diberi peringatan.
- Pilihan manual yang tidak cocok tetap dapat dilihat dengan peringatan, tetapi
  tidak disimpan sebagai pilihan otomatis aman. Impor LRC berlaku untuk lagu aktif
  dan tidak disimpan permanen. Periksa ulang mengambil kandidat baru; Pilihan
  otomatis menghapus pilihan dan offset lagu itu.
- Extension mengirim heartbeat sekitar 500 ms; kedaluwarsa tiga detik. Jam monotonic
  mengikuti pause/seek/lagu baru. Sumber waktu quantized dibatasi satu detik di depan
  pembacaan terakhir. Klik ganda baris melakukan seek jika timeline aman.
- Audio memakai offset Shazam + waktu sejak awal cuplikan, dengan TTL 35 detik.
  Keheningan menahan waktu; suara ada tidak membuktikan lagu sama. Pause, seek,
  perubahan lagu, campuran suara dan speed berbeda tidak dapat diverifikasi dari
  metadata audio saja. UI selalu menyebut posisi ini **perkiraan**.
- Kesamaan metadata/timestamp bukan bukti sinkronisasi dengan vokal. Belum ada
  pengujian sinkronisasi vokal nyata. Capture Discord dan pengenalan dua lagu telah
  berhasil pada sesi Windows ini; lihat VALIDATION.md untuk batas buktinya.

## Privasi dan audio

GUI tidak menerima aktivasi audio lewat argumen CLI atau preferensi tersimpan. Hanya tombol
manual dan persetujuan dialog yang bisa memulai capture. WASAPI memilih loopback
untuk output default; perangkat yang bukan loopback ditolak tanpa fallback mic.
Mengganti perangkat output saat aktif mungkin memerlukan Matikan lalu aktifkan lagi.

Cuplikan 12 detik float PCM di-downmix/resample ke mono PCM16 44100 Hz dalam RAM,
dienkode sebagai WAV di RAM, lalu dikirim ke stdin `LirisWorker.exe`. Worker memakai
implementasi bersama `backend/shazamio_worker.py` dan ShazamIO 0.9.0. Audio tidak
ditulis ke file oleh aplikasi. Signature pengenalan dikirim ke layanan Shazam;
ShazamIO adalah API tidak resmi. Output percakapan juga dapat ikut dianalisis.

Satu worker aktif, silence gate, jeda request, timeout, epoch sesi dan epoch prioritas
extension membatasi pekerjaan. Extension bermain/iklan membatalkan worker dan
mengosongkan buffer; capture masih aktif dan indikator tetap aktif sampai dimatikan.
Matikan membatalkan hasil antrean, membunuh worker dan menutup stream. Status
Menghentikan tetap ditampilkan selama penghentian berlangsung.

Cache lirik/pengaturan/metadata browser berada di `%LOCALAPPDATA%\Liris`.
LRCLIB menerima judul/artis/durasi atau query pencarian. Tidak ada telemetry.
Native host memvalidasi origin extension dan ukuran frame, tidak menyimpan cookie,
dan membatasi command ke lagu yang sama serta heartbeat segar. Session di-scope per
port agar tab ID dua browser tidak bertabrakan.

## Build untuk pengembang

Python **3.13 x64**, Windows, koneksi untuk mengunduh wheel:

```powershell
cd windows
.\build.ps1
```

`requirements.lock` mem-pin dependensi Windows, termasuk seluruh dependensi backend
yang dipakai Mac. PyInstaller membangun GUI, native host dan worker terpisah yang
berbagi runtime; `package.py` menyertakan inventaris dan lisensi upstream dalam ZIP.
Qt memakai DLL terpisah; sumber Qt dan ketentuan LGPL tersedia di
https://code.qt.io/cgit/pyside/pyside-setup.git/ dan https://www.qt.io/licensing/.
Tidak ada build step yang membuka capture atau memanggil Shazam recognition.

```powershell
.venv\Scripts\python.exe -m unittest discover -s tests -v
.venv\Scripts\python.exe main.py
.venv\Scripts\python.exe verify_package.py
```

`verify_package.py` menguji bundle dengan PATH tanpa Python, direktori kerja lain,
UI startup/reconnect/overlay, worker `--check` (import saja), serta pertukaran native
messaging menggunakan fixture sintetis. Tidak merekam atau mengirim audio.

Lihat [VALIDATION.md](VALIDATION.md) untuk status bukti, batasan, dan pengujian nyata
yang masih perlu dilakukan dengan izin pengguna. Arsitektur: [ARCHITECTURE.md](ARCHITECTURE.md).

Probe developer `live_audio_probe.py` terpisah dari aplikasi dan tidak masuk paket,
startup, build atau CI. Hanya jalankan sesudah izin eksplisit sesi capture/signature:

```powershell
.venv\Scripts\python.exe live_audio_probe.py --consent-system-output --recognize --seconds 45 --report .test-data/live.json
```

Tanpa `--recognize`, probe hanya mengukur output loopback dan menahan worker. Laporan
berisi metrik dan metadata hasil, tidak menyimpan sampel audio. Probe memakai capture
engine source dengan `LirisWorker.exe` paket; jangan menyebutnya uji GUI paket.
