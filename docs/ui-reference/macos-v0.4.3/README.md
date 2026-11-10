# Liris Mac v0.4.3 — acuan UI untuk Windows

Dibuat 10 November 2026 dari executable native v0.4.3, berdasarkan source commit c2516aa57595cdd22295b0f8e701528d5091a5a2. Tidak ada source aplikasi, setting pengguna, atau release binary yang diubah untuk menghasilkan paket ini.

Semua screenshot menggunakan data demo orisinal, bukan musik pengguna. Indikator audio aktif adalah state simulasi; tidak ada capture sistem, microphone, atau request Shazam/LRCLIB. Jangan menafsirkan badge demo sebagai kombinasi state produksi yang wajib ditiru.

| Berkas | Isi |
| --- | --- |
| 01-main-audio-off.png | Utama dengan lirik demo, audio off |
| 02-main-audio-active.png | Utama dengan status capture aktif simulasi |
| 03-sync-uncertain.png | Peringatan kecocokan timing, pemilihan versi |
| 04-appearance.png | Pengaturan tema/ukuran/opasitas + preview |
| 05-connection-guide.png | Bagian atas panduan; halaman dapat discroll |
| 06-overlay-audio-active.png | Overlay dengan indikator aktif dan Matikan |
| 07-empty.png | Tampilan tanpa lagu |
| PROMPT-WINDOWS.md | Instruksi revisi UI yang siap dikirim ke sesi Windows |

Viewport utama: 1220×790 logical points, render Retina PNG 2440×1580. Overlay: 800×180 logical points, PNG 1600×360. Pengaturan render: lime, font overlay 28, opasitas overlay 88%. Screenshot adalah render native offscreen dari view aplikasi, bukan tangkapan seluruh desktop/Dock.

Beberapa area scroll dan lirik memakai fade mask; jangan menyalin clipping atau opacity teks secara membuta. Tingkatkan keterbacaan sesuai Windows, pertahankan native window controls, aksesibilitas, dan DPI scaling. Gunakan Segoe UI alih-alih membundel font Apple.

Sumber desain: Sources/LirisApp/{ContentView,DetailViews,LirisApp,AudioCaptureStatus,OverlayController,SyncStatusView}.swift pada commit di atas. Prioritaskan gambar dalam folder ini daripada screenshot lama langsung di docs/.

## Mengakses dari sesi Windows

Unduh ZIP acuan yang dilampirkan pada GitHub Release v0.4.3, ekstrak dan buka PNG + PROMPT-WINDOWS.md. Atau lihat folder pada branch codex/macos-ui-reference. Tidak perlu mengganti branch Windows atau merge kode Mac untuk mengakses referensi.
