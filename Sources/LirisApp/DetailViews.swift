import SwiftUI
import LirisCore

struct AppearanceControls: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 11) {
                Text("Warna sorotan").font(.system(size: 11)).foregroundStyle(Palette.muted)
                HStack(spacing: 12) {
                    ForEach(["Lime", "Lavender", "Peach"], id: \.self) { name in
                        Button { model.accentName = name } label: {
                            Circle().fill(color(name)).frame(width: 23, height: 23)
                                .padding(4).overlay(Circle().strokeBorder(model.accentName == name ? color(name).opacity(0.7) : .clear, lineWidth: 1))
                        }.buttonStyle(.plain).accessibilityLabel("Warna \(name)").help(name)
                    }
                }
            }
            VStack(spacing: 9) {
                HStack { Text("Ukuran lirik overlay"); Spacer(); Text("\(Int(model.fontSize)) px").monospacedDigit() }
                Slider(value: $model.fontSize, in: 18...42).controlSize(.mini).accessibilityLabel("Ukuran lirik overlay")
                HStack { Text("Aa").font(.system(size: 10)); Spacer(); Text("Aa").font(.system(size: 16)) }
            }.font(.system(size: 11)).foregroundStyle(Palette.muted)
            VStack(spacing: 9) {
                HStack { Text("Latar overlay"); Spacer(); Text("\(Int(model.opacity * 100))%").monospacedDigit() }
                Slider(value: $model.opacity, in: 0.15...1).controlSize(.mini).accessibilityLabel("Opasitas latar overlay")
            }.font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
    }

    private func color(_ name: String) -> Color {
        switch name {
        case "Lavender": Color(red: 0.73, green: 0.65, blue: 1)
        case "Peach": Color(red: 1, green: 0.72, blue: 0.53)
        default: Color(red: 0.79, green: 0.94, blue: 0.48)
        }
    }
}

struct SyncControls: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Eyebrow(text: "PAS DI WAKTUNYA")
            Text("Penyesuaian sinkronisasi").font(.system(size: 11)).foregroundStyle(Palette.muted)
            HStack(spacing: 0) {
                Button { model.offset = max(-10, model.offset - 0.2) } label: { Image(systemName: "minus").frame(width: 37, height: 33) }
                    .buttonStyle(.plain).accessibilityLabel("Mundurkan lirik 0,2 detik")
                Spacer()
                Text(String(format: "%+.1f s", model.offset)).font(.system(size: 14, weight: .medium, design: .monospaced))
                Spacer()
                Button { model.offset = min(10, model.offset + 0.2) } label: { Image(systemName: "plus").frame(width: 37, height: 33) }
                    .buttonStyle(.plain).accessibilityLabel("Majukan lirik 0,2 detik")
            }.background(Palette.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Text("+ lebih cepat · − lebih lambat").font(.system(size: 9)).foregroundStyle(Palette.muted)
                Spacer()
                Button("Reset") { model.offset = 0 }.font(.system(size: 9)).buttonStyle(.plain).foregroundStyle(model.accent)
            }
        }
    }
}

struct AppearancePage: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bikin ruang dengarmu sendiri.").font(.system(size: 25, weight: .medium, design: .serif))
                    Text("Warna dan ukuran akan langsung diterapkan ke overlay, lalu disimpan di Mac ini.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                HStack(alignment: .top, spacing: 30) {
                    VStack(spacing: 24) {
                        AppearanceControls()
                        Divider()
                        SyncControls()
                        Toggle("Kunci overlay (klik menembus)", isOn: $model.overlayLocked)
                            .toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
                            .onChange(of: model.overlayLocked) { _, _ in model.overlayController.updateLock() }
                    }.frame(width: 245).padding(24).background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: "PRATINJAU OVERLAY")
                        VStack(spacing: 12) {
                            Text("LIRIS · \(model.hasTrack ? model.title : "Musik favoritmu")").font(.system(size: 8, weight: .medium)).tracking(1.5).foregroundStyle(.white.opacity(0.4))
                            Text(model.currentText).font(.system(size: model.fontSize, weight: .semibold)).foregroundStyle(model.accent).multilineTextAlignment(.center).lineLimit(3)
                            Text(model.nextText.isEmpty ? "Ada cerita di setiap nada." : model.nextText).font(.system(size: 15)).foregroundStyle(.white.opacity(0.45)).lineLimit(2)
                        }.padding(28).frame(maxWidth: .infinity, minHeight: 200)
                            .background(Palette.background.opacity(model.opacity), in: RoundedRectangle(cornerRadius: 18))
                            .padding(20).background(LinearGradient(colors: [.gray.opacity(0.12), model.accent.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
                        Button { model.toggleOverlay() } label: { Label(model.overlayVisible ? "Sembunyikan overlay" : "Buka overlay", systemImage: "rectangle.on.rectangle") }
                            .buttonStyle(AccentButton(color: model.accent))
                        Text("Tarik pegangan atas untuk memindahkan overlay. Klik ikon gembok untuk mengunci atau membuka kunci. ⇧⌘L menampilkan atau menyembunyikan overlay saat aplikasi aktif.")
                            .font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(5)
                    }.frame(maxWidth: .infinity)
                }
            }.padding(32)
        }
    }
}

struct SearchView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var queryFocused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Temukan kata-kata yang kamu cari.").font(.system(size: 26, weight: .medium, design: .serif))
            Text("Cari judul dan artis. Pilih versi yang sama dengan musikmu agar waktunya pas.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                    TextField("Judul lagu atau nama artis…", text: $model.searchQuery).textFieldStyle(.plain)
                        .font(.system(size: 14)).onSubmit { model.search() }.focused($queryFocused)
                }.padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                Button("Cari lirik") { model.search() }.buttonStyle(AccentButton(color: model.accent)).disabled(model.searching || model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button { model.importLRC() } label: { Label("Impor LRC", systemImage: "square.and.arrow.down") }.buttonStyle(QuietButton())
            }
            if model.connected {
                Label("Lirik yang dipilih akan mengikuti posisi lagu yang sedang diputar.", systemImage: "link")
                    .font(.system(size: 11)).foregroundStyle(model.accent)
            } else {
                Text("Tanpa koneksi pemutar, gunakan timer manual atau hubungkan YouTube Music lebih dulu.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            if model.searching {
                Spacer(); ProgressView("Mencari di LRCLIB…").frame(maxWidth: .infinity); Spacer()
            } else if let error = model.searchError {
                ErrorNotice(message: error); Spacer()
            } else if model.didSearch && model.searchResults.isEmpty {
                ContentUnavailableView("Belum ada hasil", systemImage: "text.magnifyingglass", description: Text("Coba judul yang lebih singkat atau tambahkan nama artis."))
            } else if model.searchResults.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "text.quote").font(.system(size: 42, weight: .light)).foregroundStyle(model.accent.opacity(0.65))
                    Text("Setiap lagu punya ceritanya.").font(.system(size: 20, design: .serif))
                    Text("Mulai dari lagu yang sedang kamu dengarkan.").font(.system(size: 12)).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.searchResults) { record in
                            Button { model.select(record) } label: {
                                HStack(spacing: 15) {
                                    Image(systemName: "music.note").font(.system(size: 18)).foregroundStyle(model.accent)
                                        .frame(width: 44, height: 44).background(model.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(record.trackName).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                        Text([record.artistName, record.albumName ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(record.instrumental ? "INSTRUMENTAL" : record.hasSync ? "SYNCED" : "TANPA TIMESTAMP")
                                        .font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(record.hasSync ? model.accent : Palette.muted)
                                    Text(TimeLabel.format(record.duration)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted).frame(width: 40)
                                    Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundStyle(Palette.muted)
                                }.padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }.padding(32).onAppear { queryFocused = true }
    }
}

struct ConnectionGuide: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "SATU KALI PENGATURAN")
                        Text("YouTube Music,\nsekarang lebih dekat.").font(.system(size: 33, weight: .medium, design: .serif)).lineSpacing(3)
                        Text("Musik tetap diputar di browser favoritmu. Liris mengikuti judul dan posisi lagunya.")
                            .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
                    }
                    Spacer()
                    Image(systemName: "play.rectangle.on.rectangle").font(.system(size: 57, weight: .ultraLight)).foregroundStyle(model.accent.opacity(0.7)).padding(.top, 25)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mode Auto · tanpa pengaturan JavaScript Brave").font(.headline)
                    Text("1. Buka folder extension dan halaman brave://extensions. Aktifkan Developer mode → Load unpacked → pilih folder AutoExtension yang dibuka. Setelah itu muat ulang tab YouTube / YouTube Music.\n2. Pilih sumber Auto di Liris, lalu Hubungkan. Tab yang bermain akan dipilih otomatis. Integrasi lama tetap tersedia lewat sumber YouTube Music.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                    Button("Buka extension dan Brave") { model.openAutoExtension() }.buttonStyle(QuietButton())
                    Divider()
                    Text("Discord / audio sistem").font(.headline)
                    Button("Buka izin Screen & System Audio Recording") { model.openAudioPrivacy() }.buttonStyle(QuietButton())
                    Text(AutoHub.shared.audio.configured ? "ShazamIO mengenali cuplikan output sistem lewat layanan online Shazam. macOS meminta izin audio sistem; tidak memakai mikrofon. Suara percakapan juga dapat masuk cuplikan. Pengenalan ditahan saat YouTube/YouTube Music bermain lewat extension." : "Runtime ShazamIO belum tersedia. Jalankan scripts/setup-shazamio.sh lalu build ulang aplikasi.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                    Text("Aktifkan manual setiap sesi. Hubungkan tidak menyalakan audio. Saat mengobrol, matikan pengenalan agar percakapan tidak ikut dianalisis.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                    AudioCaptureStatusView()
                }.padding(20).background(Palette.card, in: RoundedRectangle(cornerRadius: 13))
                step("01", title: "Buka YouTube Music di browser", detail: "Gunakan Google Chrome, Brave, Edge, atau Safari. Putar satu lagu di music.youtube.com. Untuk hasil konsisten, gunakan satu tab pemutar.") {
                    Button { model.openYouTube() } label: { Label("Buka YouTube Music", systemImage: "arrow.up.right") }.buttonStyle(QuietButton())
                }
                step("02", title: "Izinkan browser menerima Apple Events", detail: "Chrome / Brave / Edge: menu View → Developer → Allow JavaScript from Apple Events.\n\nSafari: Settings → Advanced → Show features for web developers. Lalu Settings → Developer → Automation → Allow JavaScript from Apple Events. Pada versi lama, opsi ini ada di menu Develop.") {
                    Text("Pengaturan ini harus kamu aktifkan sendiri di browser.").font(.system(size: 10)).foregroundStyle(model.accent)
                }
                step("03", title: "Hubungkan dan izinkan Automation", detail: "Di Sedang diputar, pilih YouTube Music dan browser yang sesuai, lalu klik Hubungkan. Pilih Allow pada dialog macOS yang mengizinkan Liris mengakses browser.") {
                    HStack {
                        Button("Ke pemutar") { model.section = .listening }.buttonStyle(AccentButton(color: model.accent))
                        Button("Buka izin Automation") { model.openAutomation() }.buttonStyle(QuietButton())
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Label("Yang perlu kamu tahu", systemImage: "info.circle").font(.system(size: 13, weight: .semibold))
                    Text("Liris membaca metadata dan waktu pemutaran dari tab YouTube Music di browser yang kamu pilih. Judul, artis, album, dan durasi dikirim ke LRCLIB untuk menemukan lirik. Sampul album dimuat dari alamat yang diberikan pemutar. Lirik yang ditemukan disimpan di cache Mac ini.")
                    Text("Jalur extension dan YouTube Music lama tidak memerlukan capture audio. Pengenalan audio sistem bersifat opsional, diaktifkan manual, dan memerlukan izin capture macOS; mikrofon tidak dibuka. Koneksi internet diperlukan untuk lirik baru. Firefox dan aplikasi YouTube Music pihak ketiga belum didukung.")
                    Text("Spotify dan Apple Music desktop juga tersedia: pilih sumbernya, klik Hubungkan, lalu izinkan Automation. Pencarian manual dan impor LRC tetap bisa digunakan tanpa integrasi pemutar.")
                }.font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(5)
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card, in: RoundedRectangle(cornerRadius: 13))
                HStack {
                    Text("Mau lihat tampilannya lebih dulu?").font(.system(size: 12)).foregroundStyle(Palette.muted)
                    Button("Jalankan demo visual") { model.startDemo() }.buttonStyle(QuietButton())
                }
            }.padding(32)
        }
    }

    private func step<Content: View>(_ number: String, title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Text(number).font(.system(size: 15, weight: .medium, design: .monospaced)).foregroundStyle(model.accent)
                .frame(width: 37, height: 37).background(model.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 11) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                content()
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(22).background(Palette.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.line))
    }
}
