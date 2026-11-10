# Hasil verifikasi lokal

Tanggal: 10 November 2026. Lingkungan: Mac Apple Silicon, macOS 27.2, Swift 6.4.2 / Command Line Tools.

- Build release `Liris.app`: berhasil, executable arm64.
- Penandatanganan ad hoc dengan entitlement Automation: `codesign --verify --deep --strict` berhasil.
- Swift Testing: 12 tes lulus (parser LRC, timestamp, offset, seek mundur, pencocokan lagu, URL encoding, cache memori/disk, rate limit, dan respons non-JSON).
- Node.js: 6 tes kontrak adapter browser lulus (snapshot metadata/waktu, pause/buffering/ended, pemutar tidak tersedia, nilai non-finite, Unicode/fallback metadata, iklan).
- Validasi paket: resource JavaScript ditemukan. Skrip deteksi dan kontrol dikompilasi untuk Chrome, Brave, Safari, Edge; skrip Spotify dan Apple Music juga dikompilasi. Tidak ada Apple Events pemutaran yang dijalankan dalam pemeriksaan ini.
- Koneksi HTTPS langsung ke LRCLIB: HTTP 200 untuk metadata lagu Evaluasi / Hindia, durasi 194 detik, lirik tersinkron tersedia. Isi lirik tidak disalin ke berkas proyek.
- Render native SwiftUI diperiksa pada halaman awal, demo lirik, dan overlay. Lihat `welcome.png`, `preview.png`, dan `overlay.png`.
- `bash -n` untuk skrip shell serta `plutil -lint` untuk Info.plist/entitlements: lulus.

## Pengujian yang masih memerlukan pengguna

Sinkronisasi pada tab YouTube Music nyata belum diverifikasi. Pengguna perlu mengaktifkan Allow JavaScript from Apple Events di Brave serta izin Automation untuk Liris, lalu menekan Hubungkan. Uji pergantian lagu, pause/resume, seek, iklan, overlay, dan koreksi waktu pada lagu yang diputar. Keberhasilan kompilasi skrip dan tes fixture tidak membuktikan bahwa struktur halaman YouTube Music saat ini persis sama dengan fixture.

Belum diuji pada Mac Intel, versi macOS lain, distribusi Developer ID/notarization, atau browser selain empat browser yang tercantum.

## Perbaikan sinkronisasi 0.1.1

Pemeriksaan baca-saja pada tab YouTube Music nyata di Brave menemukan lagu I Don't Love You / My Chemical Romance pada posisi 232,676 detik (dijeda). UI pemutar menunjukkan total 239 detik. `video.duration` berubah antara 298,551, 328,505, dan 358,459 detik meskipun posisi tetap, sedangkan `#progress-bar[aria-valuemax]` tetap 239. Adapter kini memprioritaskan durasi progress bar, disusul teks waktu UI, lalu durasi media sebagai fallback. Pembacaan pada tab yang sama setelah perbaikan menghasilkan posisi 232,676 detik dan durasi 239 detik.

Cache lokal memuat record LRCLIB 563657 yang mengaku berdurasi 239 detik tetapi memiliki timestamp isi sampai 255,23 detik. Record ini beserta versi single 33303505 menyimpan timing yang identik. Dengan persetujuan pengguna, pencarian online menemukan delapan kandidat lain yang cocok judul/artis/durasinya dan memiliki timestamp dalam batas akhir lagu. Salah satunya record 7473665, durasi 239 detik, timestamp isi pertama 26,22 dan terakhir 224,42 detik. Ini memvalidasi batas waktu, belum membuktikan setiap kata tepat secara auditori.

Hasil API exact dan cache kini sama-sama diperiksa; record dengan timestamp isi melewati durasi lagu lebih dari tiga detik dilewati dan diganti kandidat valid dari pencarian. Penanda akhir kosong tidak menggugurkan record. Durasi yang baru diketahui memicu pencocokan ulang. Kontrol playback juga memakai identitas snapshot yang sama saat YouTube Music memutar dari halaman utama tanpa parameter `v`.

Setelah perbaikan: 14 tes Swift dan 9 tes JavaScript lulus, termasuk regresi durasi buffer yang terus membesar dan penolakan cache/hasil exact dengan timing melampaui akhir lagu. Verifikasi auditori setelah menekan Hubungkan tetap dilakukan pengguna.

## Perbaikan sinkronisasi 0.1.2

Pada laporan 21 Guns / Green Day, pembacaan lokal menemukan progress bar pada 29 detik, durasi 322 detik, dan MediaSession paused; elemen video masih menunjukkan 172,187 detik dengan durasi 321 detik. Cache lirik lokal record 3653924 berdurasi 321 detik memiliki timestamp isi dalam batas lagu, sehingga pemeriksaan batas akhir dari 0.1.1 tidak mendeteksi perbedaan sumber waktu ini.

Adapter kini memilih progress bar jika waktu media tidak sejalan dan menggunakan MediaSession untuk play/pause. Presisi waktu media tetap digunakan saat selisihnya dalam 1,25 detik. PlaybackClock baru menginterpolasi snapshot integer tanpa mengulang anchor pada angka sama, membatasi kemajuan saat sumber macet, dan mereset acuan saat seek/pause/pergantian sumber. Seek terhadap elemen media yang tidak sejalan dinonaktifkan; pengguna dapat seek langsung di browser. Play/pause diarahkan ke tombol pemutar YouTube Music.

Regresi diuji dengan angka sintetis yang mereproduksi observasi 29 versus 172,187 detik, status MediaSession yang berbeda dari media node, posisi nol, fallback teks UI, snapshot integer berulang, buffering, seek mundur, pause/resume, pergantian sumber, dan playback rate. Seluruh 19 tes Swift serta 14 tes JavaScript lulus. Paket release 0.1.2 berhasil dibangun, lolos pemeriksaan tanda tangan lokal, dan skrip untuk empat browser serta Spotify/Apple Music berhasil dikompilasi. Diagnosis dari paket final pada tab nyata menghasilkan `position=29`, `positionSource=progress`, `mediaPosition=172.187185`, `progressPosition=29`, `duration=322`, dan `playing=false`, sesuai UI. Liris dibuka kembali untuk pengujian auditori pengguna. Tidak ada pengiriman metadata 21 Guns ke layanan luar dalam investigasi ini.


## Pemeriksaan otomatis 0.2.0

Pemeriksaan ulang setelah pekerjaan terputus: seluruh 39 tes Swift pada lima suite dan 14 tes JavaScript lulus (53 total). Tes baru mencakup pemantauan sumber waktu lintas sampel, dua jam macet dan pulih, slider yang berbeda dari dua jam lain, input waktu tidak valid, ketidakpastian timing antarversi, penolakan metadata/versi salah, cache pemeriksaan offline, pilihan versi yang dipulihkan lintas instance, serta force refresh dengan timing baru pada ID record yang sama.

Build release 0.2.0 berhasil. Render native panel status uncertain diperiksa pada data demo orisinal, termasuk menu Versi lain dan tombol Periksa ulang; lihat auto-sync-uncertain.png. Ini merupakan simulasi UI dan bukan bukti kecocokan dengan vokal lagu nyata. Pilihan versi otomatis tetap berbasis metadata, struktur timestamp, dan perbandingan kandidat; tidak ada analisis audio.

Offset nonnol diingat per signature lagu di UserDefaults. Pilihan lirik yang lolos pemeriksaan struktural dan arsip perbandingan disimpan lokal. Arsip diperiksa ulang terhadap metadata saat dibaca; hasil baru untuk ID yang sama mengungguli hasil lama. Pemeriksaan online menggunakan API LRCLIB yang sama dengan fitur lirik aplikasi, tanpa audio atau kredensial akun.

Paket final lolos codesign --verify --deep --strict dan pemeriksaan resource/kompilasi skrip. Diagnosis lokal 12 sampel pada tab Brave nyata menunjukkan jam media 4074,355 detik di luar durasi lagu 187 detik. Monitor konsisten menolaknya dan memilih posisi progress 109 detik dengan health recovered; pemutar dijeda sepanjang pengamatan. Tidak ada pengiriman metadata lagu ini ke layanan luar oleh diagnosis. Liris 0.2.0 dibuka kembali dan arsip ZIP diperbarui.


## Auto gabungan 0.3.0

Build app dan helper native LirisBridge berhasil; codesign deep/strict lulus. 41 tes Swift, 14 regresi adapter lama, dan tiga tes content script extension lulus (58 total). Smoke test executable native host memeriksa framing panjang little-endian, penambahan timestamp lokal, penolakan path traversal, dan EOF tanpa menulis data di luar direktori temporer.

Native host dengan allowlist ID extension lbogacejhoidbiplndajhinepmobfphh dipasang khusus pada profil Brave. Tidak ada perubahan pada pengaturan Allow JavaScript from Apple Events. Extension folder dan halaman extensions dibuka untuk tindakan Load unpacked dari pengguna; pengujian browser ke app secara end-to-end belum dianggap lulus sebelum extension dimuat dan menghasilkan heartbeat nyata.

Mesin ScreenCaptureKit + ShazamKit dikompilasi, namun build lokal menetapkan LirisShazamEnabled=false. Tidak ada capture audio atau pencocokan Discord yang dijalankan. Jalur Discord masih memerlukan konfigurasi App ID/provisioning/signing ShazamKit dan pengujian izin serta pengenalan audio. Batas ini dinyatakan pada panduan dan tombol dinonaktifkan; mode Auto tidak mengklaim Discord sudah tersambung.


## ShazamIO 0.4.0

ShazamKit diganti ShazamIO 0.9.0 dengan Python 3.12 lokal. Tidak ada kebutuhan akun Apple Developer untuk backend ini. Dependensi terpasang dan dipin dalam backend/requirements.lock. Worker menerima WAV mono PCM16 44100 Hz lewat stdin, tanpa file audio. Capture tidak otomatis dimulai saat aplikasi dibuka.

41 tes Swift, 17 tes JavaScript dan lima tes worker Python lulus (63 total). Tes Python mencakup format/durasi cuplikan, no-match, offset tetap mengacu cuplikan, serta penolakan offset negatif/non-finite. Smoke test nada sintetis 12 detik menjalankan worker ShazamIO aktual dan selesai matched=false dengan exit 0. Tidak ada output Mac, mikrofon, atau percakapan Discord yang dipakai dalam pengujian jaringan ini.

Capture memakai ScreenCaptureKit, konversi PCM mono, silence gate dan window 12 detik. Hanya satu worker dapat aktif; timeout 23 detik pada host dan 18 detik pada request, cooldown setelah gagal, pembatalan pada stop/suppress, dan expiry hasil disertakan. Extension playing menahan worker serta mengosongkan buffer. Posisi adalah offset pengenalan ditambah waktu monotonic sejak awal cuplikan, bukan sejak jawaban diterima.

Durasi dari hasil lirik hanya untuk tampilan pada jalur recognition dan tidak dipromosikan menjadi pengukuran durasi pemutar. Status sumber waktu recognition ditandai terbatas/estimasi. Runtime Python disimpan di .runtime dalam checkout dan dirujuk dengan path absolut dari konfigurasi app; app ini belum paket Python mandiri untuk distribusi ke Mac lain. Pengujian audio lagu nyata dan izin capture macOS tetap memerlukan aktivasi pengguna melalui Panduan koneksi.


## Diagnosis Discord / audio 0.4.1

Dengan izin pengguna, uji capture lokal memperoleh callback audio dan PCM mono yang melewati window 12 detik. Uji pengenalan nyata kemudian mengenali Negoro Angin / Denny Caknan, dikonfirmasi pengguna sebagai lagu yang diputar. Uji melalui AppModel dan LRCLIB memuat record 31596625 dengan 48 baris bertimestamp; metadata record berdurasi 312 detik, timestamp isi terakhir 297,72 detik. Ini membuktikan capture, pengenalan, dan pemuatan lirik dalam diagnosis; belum membuktikan sinkronisasi vokal pada UI aplikasi normal.

Diagnosis aplikasi normal menemukan capture ditolak macOS dengan pesan “The user declined TCCs for application, window, display capture”, nol callback dan nol percobaan worker. Izin proses diagnosis CLI berbeda dari izin aplikasi yang dibuka normal. Pesan ini kini ditampilkan sebagai petunjuk izin yang dapat ditindaklanjuti; panduan menyediakan tombol menuju Screen & System Audio Recording. Capture menggunakan filter display ScreenCaptureKit dengan output audio saja. Izin audio saja belum tentu mengizinkan enumerasi/capture display yang dipakai implementasi ini.

Pengguna mengizinkan pengujian pengenalan berkelanjutan dan memberi ulang izin Liris setelah build final. Kedua kategori izin terlihat aktif di System Settings. Setelah entri diganti dan aplikasi dibuka kembali, log ScreenCaptureKit menunjukkan TCC Allow dan stream berhasil dimulai. Diagnosis normal mencatat running=true, 939 callback, dan 828183 frame PCM; level saat pemeriksaan nol (hening), sehingga pengenalan lagu dari sesi normal masih menunggu musik. File diagnosis sempat tertinggal saat macOS menutup aplikasi untuk menerapkan izin; selalu periksa updatedAt sebelum menyimpulkan error masih aktif.


Sesudah pengguna memutar musik kembali, aplikasi normal (dibuka melalui Launch Services) menerima audio level nonnol, menjalankan worker, lalu menghasilkan outcome=matched untuk Negoro Angin / Denny Caknan. Diagnosis final: running=true, callbacks=4808, convertedFrames=4240641, attempts=3, pending=false, lyricLines=48, lyricsError kosong, uiStatus=Auto · audio sistem (ShazamIO). Dengan demikian alur capture aplikasi normal → ShazamIO → pemuatan lirik telah terverifikasi. Ketepatan sinkronisasi terhadap vokal tetap memerlukan penilaian auditori pengguna; timing pengenalan audio adalah estimasi. Pengujian berkelanjutan dibiarkan aktif sesuai izin pengguna sampai tombol Matikan/Putuskan ditekan.

Paket final 0.4.1 lolos codesign deep/strict dan lint plist; ZIP diperbarui sebelum pemberian ulang izin sehingga binary dan identitas tanda tangan tidak berubah lagi selama pengujian izin.


## Kontrol audio manual 0.4.2

Preferensi autoAudioEnabled dimigrasikan/dihapus dan tidak dibaca oleh Connect. Flag startup --resume-auto-audio dihapus. Capture hanya dapat dimulai dari aksi Aktifkan audio dengan koneksi Auto aktif. Matikan tersedia pada panel status global, panduan, menu bar, dan overlay yang tidak terkunci; overlay terkunci tetap memperlihatkan indikator. Indikator mengikuti fase off/starting/active/stopping, termasuk ketika extension menahan worker namun capture masih aktif. Stop membatalkan aktivasi tertunda, membuang buffer/hasil, menghentikan worker dan stream; callback stream lama tidak boleh menghentikan sesi baru. captureMicrophone=false ditetapkan eksplisit pada macOS 15+.

41 tes LirisCore dan empat tes AppModel lulus (45 tes Swift). Tes AppModel memakai driver audio dan polling palsu: preferensi lama termasuk yang dimasukkan lagi sesudah init tidak menyalakan capture saat Connect/reconnect; hanya klik manual dapat mulai; klik ganda tidak menggandakan start; Matikan saat izin tertunda tidak menyala lagi setelah start selesai; suppression dan penghentian mendadak terpantul di indikator. Tidak ada capture, request Shazam atau pencarian lirik nyata dari tes tersebut.

Build release 0.4.2 berhasil setelah dsymutil dijalankan di luar pembatasan sandbox; tanda tangan deep/strict dan lint plist lulus. Pratinjau native aktif, suppression, mati, dan overlay diperiksa menggunakan data demo tanpa audio; panel pengaturan di sisi kanan dapat discroll agar banner dan kontrol tetap muat.

Uji UI aplikasi normal: saat dibuka terlihat Pengenalan audio mati. Klik Hubungkan → Putuskan → Hubungkan tetap membiarkan audio mati dan menampilkan tombol Aktifkan audio. Capture tidak diaktifkan kembali untuk uji ini. App ditinggalkan pada sumber Auto yang terhubung dengan audio mati, agar pengguna dapat mengaktifkannya sendiri. ZIP dist/Liris-macOS-arm64.zip diperbarui ke 0.4.2.
