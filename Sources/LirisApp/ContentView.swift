import SwiftUI
import LirisCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 205)
            Rectangle().fill(Palette.line).frame(width: 1)
            VStack(spacing: 0) {
                header
                AudioCaptureStatusView().padding(.horizontal, 30).padding(.bottom, 12)
                Rectangle().fill(Palette.line).frame(height: 1)
                Group {
                    switch model.section {
                    case .listening: ListeningView()
                    case .search: SearchView()
                    case .appearance: AppearancePage()
                    case .help: ConnectionGuide()
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
        }
        .background(Palette.background)
        .tint(model.accent)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(model.accent).frame(width: 36, height: 36)
                    Image(systemName: "waveform").font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.background)
                }
                Text("liris").font(.system(size: 29, weight: .semibold, design: .rounded)).tracking(-1.5)
            }.padding(.bottom, 10)
            Text("A LITTLE CLOSER TO THE MUSIC")
                .font(.system(size: 7, weight: .medium)).tracking(1.2).foregroundStyle(Palette.muted)
                .padding(.bottom, 42)
            Eyebrow(text: "RUANG DENGAR").padding(.bottom, 13)
            ForEach([Section.listening, .search, .appearance], id: \.self) { section in
                navButton(section).padding(.bottom, 6)
            }
            Spacer(minLength: 25)
            VStack(alignment: .leading, spacing: 13) {
                Image(systemName: "quote.opening").font(.system(size: 23)).foregroundStyle(model.accent.opacity(0.6))
                Text("Ada cerita\ndi setiap nada.").font(.system(size: 20, weight: .medium, design: .serif)).foregroundStyle(.white.opacity(0.75)).lineSpacing(4)
                Text("Beri ruang untuk mendengarnya.").font(.system(size: 10)).foregroundStyle(Palette.muted).lineSpacing(3)
            }.padding(.bottom, 32)
            navButton(.help)
            Divider().overlay(Palette.line).padding(.vertical, 18)
            HStack(spacing: 7) {
                Circle().fill(model.accent).frame(width: 5, height: 5)
                Text("NATIVE DI MAC").font(.system(size: 8, weight: .semibold)).tracking(1.2)
                Spacer()
                Text("v0.4.3").font(.system(size: 9)).foregroundStyle(Palette.muted)
            }.foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 22).padding(.top, 56).padding(.bottom, 24)
        .background(Palette.sidebar)
    }

    private func navButton(_ section: Section) -> some View {
        Button { model.section = section } label: {
            HStack(spacing: 10) {
                Image(systemName: section.symbol).font(.system(size: 14)).frame(width: 18)
                Text(section.rawValue).font(.system(size: 11, weight: model.section == section ? .semibold : .medium))
                Spacer(minLength: 0)
                if model.section == section { Circle().fill(model.accent).frame(width: 4, height: 4) }
            }.foregroundStyle(model.section == section ? model.accent : Palette.muted)
                .padding(.horizontal, 12).padding(.vertical, 13)
                .background(model.section == section ? model.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Eyebrow(text: "YOUR EVERYDAY SOUNDTRACK")
                Text(model.section == .listening ? "Musikmu, kata demi kata." : model.section.rawValue)
                    .font(.system(size: 22, weight: .medium)).tracking(-0.6)
            }
            Spacer()
            if model.demo {
                Text("DEMO · TANPA AUDIO").font(.system(size: 8, weight: .semibold)).tracking(1)
                    .foregroundStyle(model.accent).padding(9).background(model.accent.opacity(0.08), in: Capsule())
            }
            Button { model.toggleOverlay() } label: {
                Label(model.overlayVisible ? "Tutup overlay" : "Buka overlay", systemImage: "rectangle.on.rectangle")
            }.buttonStyle(QuietButton()).help("Tampilkan lirik di atas aplikasi lain · ⇧⌘L")
        }.padding(.horizontal, 30).padding(.top, 32).padding(.bottom, 23)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Circle().fill(model.connected || model.demo ? model.accent : Palette.muted).frame(width: 5, height: 5)
            Text(model.status).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(2)
            Spacer()
            Text("LYRICS BY LRCLIB").font(.system(size: 8, weight: .medium)).tracking(1.4).foregroundStyle(Palette.muted.opacity(0.65))
        }.padding(.horizontal, 30).padding(.vertical, 14)
            .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
}

struct ListeningView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 16) {
                SourceBar()
                if model.hasTrack && !model.demo { SyncStatusView() }
                if let error = model.connectionError { ErrorNotice(message: error, action: "Panduan koneksi") { model.section = .help } }
                NowPlayingCard()
                LyricStage().frame(maxHeight: .infinity)
                PlaybackBar()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            ScrollView {
              VStack(alignment: .leading, spacing: 22) {
                HStack { Eyebrow(text: "SESUAIKAN SUASANA"); Spacer(); Image(systemName: "slider.horizontal.3").foregroundStyle(Palette.muted) }
                AppearanceControls()
                Divider().overlay(Palette.line)
                SyncControls()
                Spacer(minLength: 8)
                VStack(alignment: .leading, spacing: 9) {
                    Image(systemName: "rectangle.on.rectangle").foregroundStyle(model.accent)
                    Text("Lirik tetap dekat.").font(.system(size: 17, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                    Text("Bawa lirik ke atas aplikasi lain dengan mode overlay.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    Button { model.toggleOverlay() } label: {
                        HStack { Text(model.overlayVisible ? "Sembunyikan overlay" : "Tampilkan overlay"); Spacer(); Image(systemName: "arrow.up.right") }
                    }.buttonStyle(QuietButton())
                }.padding(17).background(model.accent.opacity(0.04), in: RoundedRectangle(cornerRadius: 13))
              }.padding(20).frame(maxWidth: .infinity)
            }.frame(width: 252).frame(maxHeight: .infinity)
                .background(Palette.card.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line))
        }.padding(26)
    }
}

struct SourceBar: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        HStack(spacing: 10) {
            Picker("Sumber musik", selection: $model.source) {
                ForEach(MusicSource.allCases) { source in Label(source.rawValue, systemImage: source.symbol).tag(source) }
            }.labelsHidden().frame(width: 151)
            if model.source == .auto {
                Button("Siapkan Auto") { model.section = .help }.buttonStyle(QuietButton())
            }
            if model.source == .youtube {
                Picker("Browser", selection: $model.browser) {
                    ForEach(Browser.allCases) { Text($0.rawValue).tag($0) }
                }.labelsHidden().frame(maxWidth: 140)
            }
            Spacer(minLength: 0)
            Button(model.connected ? "Putuskan" : "Hubungkan") {
                if model.connected { model.disconnect() } else { model.connect() }
            }.buttonStyle(AccentButton(color: model.accent))
        }
    }
}

struct NowPlayingCard: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        HStack(spacing: 19) {
            AlbumArt().frame(width: 106, height: 106)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: model.demo ? "sparkles" : model.source.symbol).font(.system(size: 9))
                    Text(model.demo ? "LIRIS STUDIO · DEMO" : model.hasTrack ? "SEDANG DIPUTAR" : "SIAP MENDENGARKAN")
                        .font(.system(size: 8, weight: .semibold)).tracking(1.4)
                }.foregroundStyle(model.accent)
                Text(model.title).font(.system(size: model.hasTrack ? 25 : 23, weight: .semibold)).tracking(-0.8).lineLimit(2)
                Text(model.artist).font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(2)
                if let album = model.snapshot?.album ?? model.record?.albumName, !album.isEmpty {
                    Text(album).font(.system(size: 10)).foregroundStyle(Palette.muted.opacity(0.7)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [model.accent.opacity(0.055), Palette.card], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(Palette.line))
    }
}

struct AlbumArt: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    LinearGradient(colors: [Color(red: 0.29, green: 0.35, blue: 0.22), Color(red: 0.09, green: 0.16, blue: 0.13), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(model.accent.opacity(0.2)).blur(radius: 18).offset(x: -25, y: -20)
                    ForEach(0..<12) { i in
                        Circle().stroke(model.accent.opacity(i % 3 == 0 ? 0.18 : 0.07), lineWidth: 1)
                            .frame(width: geo.size.width * (0.24 + Double(i) * 0.075))
                    }
                    Circle().fill(model.accent.opacity(0.8)).frame(width: 13, height: 13)
                    Circle().fill(Palette.background).frame(width: 4, height: 4)
                }.frame(width: geo.size.width, height: geo.size.height)
            }
            if let raw = model.snapshot?.artwork, let url = URL(string: raw), url.scheme == "https" {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.09)))
            .accessibilityLabel("Sampul album")
    }
}

struct LyricStage: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Eyebrow(text: "DI ANTARA NADA")
                Spacer()
                if model.loading { ProgressView().controlSize(.mini) }
                else if model.record?.hasSync == true {
                    HStack(spacing: 5) { Circle().frame(width: 4, height: 4); Text("SYNCED LYRICS").tracking(1) }
                        .font(.system(size: 8, weight: .medium)).foregroundStyle(model.accent)
                }
            }.padding(.bottom, 8)
            if model.loading {
                Spacer(); ProgressView("Mencari kata untuk lagumu…").font(.system(size: 12)).foregroundStyle(Palette.muted); Spacer()
            } else if let message = model.lyricsError {
                Spacer()
                Image(systemName: "text.magnifyingglass").font(.system(size: 28)).foregroundStyle(Palette.muted).padding(.bottom, 12)
                Text(message).font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).lineLimit(4)
                HStack {
                    Button("Cari lirik") { model.searchQuery = [model.snapshot?.title, model.snapshot?.artist].compactMap { $0 }.joined(separator: " "); model.section = .search }.buttonStyle(QuietButton())
                    Button("Coba lagi") { model.loadLyrics() }.buttonStyle(QuietButton())
                }.padding(.top, 12)
                Spacer()
            } else if model.record?.instrumental == true {
                Spacer(); Image(systemName: "pianokeys").font(.system(size: 32)).foregroundStyle(model.accent)
                Text("Instrumental. Nikmati nadanya.").font(.system(size: 15)).foregroundStyle(Palette.muted).padding(.top, 16); Spacer()
            } else if !model.lines.isEmpty {
                GeometryReader { geometry in
                    ScrollViewReader { reader in
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 22) {
                                ForEach(Array(model.lines.enumerated()), id: \.element.id) { index, line in
                                    Button { model.seek(max(0, line.time - model.offset)) } label: {
                                        Text(line.text.isEmpty ? "♪" : line.text)
                                            .font(.system(size: index == model.activeIndex ? 25 : 21, weight: index == model.activeIndex ? .semibold : .medium))
                                            .tracking(-0.5).multilineTextAlignment(.center).lineSpacing(5)
                                            .foregroundStyle(index == model.activeIndex ? model.accent : .white.opacity(index < (model.activeIndex ?? 0) ? 0.22 : 0.40))
                                            .frame(maxWidth: .infinity).padding(.horizontal, 14)
                                            .padding(.vertical, 2)
                                    }.buttonStyle(.plain).id(index).disabled(!model.canSeek)
                                        .help(model.canSeek ? "Lompat ke \(TimeLabel.format(line.time))" : "Pindahkan posisi lagu langsung di YouTube Music")
                                }
                            }.padding(.vertical, max(30, geometry.size.height * 0.38))
                        }.scrollIndicators(.hidden)
                            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.17), .init(color: .black, location: 0.83), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                            .onChange(of: model.activeIndex) { _, index in
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) { reader.scrollTo(index ?? 0, anchor: .center) }
                            }
                            .onAppear { reader.scrollTo(model.activeIndex ?? 0, anchor: .center) }
                            .onChange(of: model.record?.id) { _, _ in reader.scrollTo(model.activeIndex ?? 0, anchor: .center) }
                    }
                }
            } else if let plain = model.record?.plainLyrics, !plain.isEmpty {
                Text("Lirik tersedia tanpa timestamp.").font(.system(size: 10)).foregroundStyle(model.accent).padding(.top, 10)
                ScrollView { Text(plain).font(.system(size: 18, weight: .medium)).lineSpacing(12).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7)).padding(16).frame(maxWidth: .infinity) }
            } else {
                Spacer()
                Image(systemName: "waveform.path").font(.system(size: 39, weight: .ultraLight)).foregroundStyle(model.accent.opacity(0.7))
                Text(model.source == .auto && model.connected ? AutoHub.shared.audio.progressStatus : "Satu lagu. Seribu rasa.").font(.system(size: model.source == .auto && model.connected ? 16 : 24, weight: .medium, design: .serif)).padding(.top, 17)
                Text("Putar lagu di YouTube Music, lalu klik Hubungkan.\nLirik akan mengikuti dari bait pertama.")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).lineSpacing(5).padding(.top, 8)
                HStack(spacing: 12) {
                    Button("Panduan koneksi") { model.section = .help }.buttonStyle(QuietButton())
                    Button("Coba demo") { model.startDemo() }.buttonStyle(QuietButton())
                }.padding(.top, 21)
                Spacer()
            }
        }.padding(.horizontal, 10).padding(.top, 10).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlaybackBar: View {
    @EnvironmentObject private var model: AppModel
    @ViewState private var scrubPosition: Double?
    var body: some View {
        VStack(spacing: 13) {
            HStack(spacing: 10) {
                Text(TimeLabel.format(model.position)).frame(width: 34, alignment: .leading)
                Slider(value: Binding(get: { scrubPosition ?? model.position }, set: { scrubPosition = $0 }), in: 0...max(1, model.duration), onEditingChanged: { editing in
                    if !editing, let value = scrubPosition { model.seek(value); scrubPosition = nil }
                })
                    .controlSize(.mini).disabled(!model.canSeek || model.duration <= 0).accessibilityLabel("Posisi lagu")
                    .help(model.canSeek ? "Posisi lagu" : "Pindahkan posisi lagu langsung di YouTube Music")
                Text(TimeLabel.format(model.duration)).frame(width: 34, alignment: .trailing)
            }.font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
            HStack {
                Button { model.importLRC() } label: { Label("Impor LRC", systemImage: "square.and.arrow.down").font(.system(size: 10)) }
                    .buttonStyle(.plain).foregroundStyle(Palette.muted)
                Spacer()
                Button { model.seek(model.position - 5) } label: { Image(systemName: "gobackward.5").font(.system(size: 19)) }
                    .buttonStyle(.plain).disabled(!model.canSeek).accessibilityLabel("Mundur 5 detik")
                Button { model.togglePlayback() } label: {
                    Image(systemName: model.playing ? "pause.fill" : "play.fill").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.background).frame(width: 42, height: 42).background(model.accent, in: Circle())
                }.buttonStyle(.plain).disabled(!model.hasTrack).padding(.horizontal, 13).accessibilityLabel(model.playing ? "Jeda" : "Putar")
                Button { model.seek(model.position + 5) } label: { Image(systemName: "goforward.5").font(.system(size: 19)) }
                    .buttonStyle(.plain).disabled(!model.canSeek).accessibilityLabel("Maju 5 detik")
                Spacer()
                Text(model.connected ? "LIVE" : "TIMER MANUAL")
                    .font(.system(size: 8, weight: .semibold)).tracking(1.2).foregroundStyle(Palette.muted).frame(width: 83, alignment: .trailing)
            }
        }.padding(.top, 12).overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
}

struct ErrorNotice: View {
    let message: String
    var action: String? = nil
    var perform: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.circle").font(.system(size: 11)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            if let action { Button(action) { perform?() }.font(.system(size: 11, weight: .semibold)).buttonStyle(.plain) }
        }.foregroundStyle(Color.orange.opacity(0.9)).padding(13).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}
