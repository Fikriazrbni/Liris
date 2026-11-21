import SwiftUI
import LirisCore

struct AppearanceControls: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 11) {
                Text("Highlight color").font(.system(size: 11)).foregroundStyle(Palette.muted)
                HStack(spacing: 12) {
                    ForEach(["Lime", "Lavender", "Peach"], id: \.self) { name in
                        Button { model.accentName = name } label: {
                            Circle().fill(color(name)).frame(width: 23, height: 23)
                                .padding(4).overlay(Circle().strokeBorder(model.accentName == name ? color(name).opacity(0.7) : .clear, lineWidth: 1))
                        }.buttonStyle(.plain).accessibilityLabel("\(name) highlight color").help(name)
                    }
                }
            }
            VStack(spacing: 9) {
                HStack { Text("Overlay lyric size"); Spacer(); Text("\(Int(model.fontSize)) px").monospacedDigit() }
                Slider(value: $model.fontSize, in: 18...42).controlSize(.mini).accessibilityLabel("Overlay lyric size")
                HStack { Text("Aa").font(.system(size: 10)); Spacer(); Text("Aa").font(.system(size: 16)) }
            }.font(.system(size: 11)).foregroundStyle(Palette.muted)
            VStack(spacing: 9) {
                HStack { Text("Overlay background"); Spacer(); Text("\(Int(model.opacity * 100))%").monospacedDigit() }
                Slider(value: $model.opacity, in: 0.15...1).controlSize(.mini).accessibilityLabel("Overlay background opacity")
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
            Eyebrow(text: "TIMING")
            Text("Lyrics timing adjustment").font(.system(size: 11)).foregroundStyle(Palette.muted)
            HStack(spacing: 0) {
                Button { model.offset = max(-10, model.offset - 0.2) } label: { Image(systemName: "minus").frame(width: 37, height: 33) }
                    .buttonStyle(.plain).accessibilityLabel("Delay lyrics by 0.2 seconds")
                Spacer()
                Text(String(format: "%+.1f s", model.offset)).font(.system(size: 14, weight: .medium, design: .monospaced))
                Spacer()
                Button { model.offset = min(10, model.offset + 0.2) } label: { Image(systemName: "plus").frame(width: 37, height: 33) }
                    .buttonStyle(.plain).accessibilityLabel("Advance lyrics by 0.2 seconds")
            }.background(Palette.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Text("+ earlier · − later").font(.system(size: 9)).foregroundStyle(Palette.muted)
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
                    Text("Make the lyrics your own.").font(.system(size: 25, weight: .medium, design: .serif))
                    Text("Color and size changes appear in the overlay immediately and are saved on this Mac.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                HStack(alignment: .top, spacing: 30) {
                    VStack(spacing: 24) {
                        AppearanceControls()
                        Divider()
                        SyncControls()
                        Toggle("Lock overlay (click-through)", isOn: $model.overlayLocked)
                            .toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
                            .onChange(of: model.overlayLocked) { _, _ in model.overlayController.updateLock() }
                    }.frame(width: 245).padding(24).background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: "OVERLAY PREVIEW")
                        VStack(spacing: 12) {
                            Text("LIRIS · \(model.hasTrack ? model.title : "Your favorite music")").font(.system(size: 8, weight: .medium)).tracking(1.5).foregroundStyle(.white.opacity(0.4))
                            Text(model.currentText).font(.system(size: model.fontSize, weight: .semibold)).foregroundStyle(model.accent).multilineTextAlignment(.center).lineLimit(3)
                            Text(model.nextText.isEmpty ? "A story in every note." : model.nextText).font(.system(size: 15)).foregroundStyle(.white.opacity(0.45)).lineLimit(2)
                        }.padding(28).frame(maxWidth: .infinity, minHeight: 200)
                            .background(Palette.background.opacity(model.opacity), in: RoundedRectangle(cornerRadius: 18))
                            .padding(20).background(LinearGradient(colors: [.gray.opacity(0.12), model.accent.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
                        Button { model.toggleOverlay() } label: { Label(model.overlayVisible ? "Hide Overlay" : "Open Overlay", systemImage: "rectangle.on.rectangle") }
                            .buttonStyle(AccentButton(color: model.accent))
                        Text("Drag the top handle to move the overlay. Click the padlock to lock or unlock it. Press ⇧⌘L to show or hide the overlay while Liris is active.")
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
            Text("Find the lyrics to your song.").font(.system(size: 26, weight: .medium, design: .serif))
            Text("Search by title and artist. Choose the version that matches your recording.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                    TextField("Song title or artist…", text: $model.searchQuery).textFieldStyle(.plain)
                        .font(.system(size: 14)).onSubmit { model.search() }.focused($queryFocused)
                }.padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                Button("Find Lyrics") { model.search() }.buttonStyle(AccentButton(color: model.accent)).disabled(model.searching || model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button { model.importLRC() } label: { Label("Import LRC", systemImage: "square.and.arrow.down") }.buttonStyle(QuietButton())
            }
            if model.connected {
                Label("Selected lyrics follow the current playback position.", systemImage: "link")
                    .font(.system(size: 11)).foregroundStyle(model.accent)
            } else {
                Text("Use the manual timer or connect YouTube Music to follow playback.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            if model.searching {
                Spacer(); ProgressView("Searching LRCLIB…").frame(maxWidth: .infinity); Spacer()
            } else if let error = model.searchError {
                ErrorNotice(message: error); Spacer()
            } else if model.didSearch && model.searchResults.isEmpty {
                ContentUnavailableView("No results", systemImage: "text.magnifyingglass", description: Text("Try a shorter title or add the artist’s name."))
            } else if model.searchResults.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "text.quote").font(.system(size: 42, weight: .light)).foregroundStyle(model.accent.opacity(0.65))
                    Text("Every song has a story.").font(.system(size: 20, design: .serif))
                    Text("Start with the song you’re listening to.").font(.system(size: 12)).foregroundStyle(Palette.muted)
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
                                    Text(record.instrumental ? "INSTRUMENTAL" : record.hasSync ? "SYNCED" : "UNTIMED")
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
                        Eyebrow(text: "ONE-TIME SETUP")
                        Text("Connect\nYouTube Music").font(.system(size: 33, weight: .medium, design: .serif)).lineSpacing(3)
                        Text("Play music in your browser. Liris follows the title and playback position.")
                            .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
                    }
                    Spacer()
                    Image(systemName: "play.rectangle.on.rectangle").font(.system(size: 57, weight: .ultraLight)).foregroundStyle(model.accent.opacity(0.7)).padding(.top, 25)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Auto mode with the Brave extension").font(.headline)
                    Text("1. Open the extension folder and brave://extensions. Turn on Developer mode, click Load unpacked, and select the AutoExtension folder. Reload your YouTube or YouTube Music tab.\n2. In Liris, select Auto and click Connect. Liris follows the tab playing music. For the direct browser connection, select YouTube Music instead.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                    Button("Open Extension and Brave") { model.openAutoExtension() }.buttonStyle(QuietButton())
                    Divider()
                    Text("Discord and system audio").font(.headline)
                    Button("Open Screen & System Audio Recording Settings") { model.openAudioPrivacy() }.buttonStyle(QuietButton())
                    Text(AutoHub.shared.audio.configured ? "ShazamIO identifies samples of system audio through Shazam’s online service. macOS asks for system audio permission. Liris leaves the microphone off. Samples can include conversations you hear. Recognition pauses when YouTube or YouTube Music plays through the extension." : "The ShazamIO runtime is missing. Run scripts/setup-shazamio.sh and rebuild the app.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                    Text("Enable recognition manually for each session. Turn it off during calls to keep conversations out of the samples.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                    AudioCaptureStatusView()
                }.padding(20).background(Palette.card, in: RoundedRectangle(cornerRadius: 13))
                step("01", title: "Open YouTube Music in your browser", detail: "Play a song at music.youtube.com in Chrome, Brave, Edge, or Safari. Use a single playback tab for consistent results.") {
                    Button { model.openYouTube() } label: { Label("Open YouTube Music", systemImage: "arrow.up.right") }.buttonStyle(QuietButton())
                }
                step("02", title: "Allow JavaScript from Apple Events", detail: "Chrome, Brave, or Edge: open View → Developer → Allow JavaScript from Apple Events.\n\nSafari: open Settings → Advanced → Show features for web developers, then Settings → Developer → Automation → Allow JavaScript from Apple Events. In older Safari versions, look in the Develop menu.") {
                    Text("Turn this setting on in your browser.").font(.system(size: 10)).foregroundStyle(model.accent)
                }
                step("03", title: "Connect and grant Automation access", detail: "In Now Playing, select YouTube Music and your browser, then click Connect. When macOS asks whether Liris can control your browser, click Allow.") {
                    HStack {
                        Button("Go to Player") { model.section = .listening }.buttonStyle(AccentButton(color: model.accent))
                        Button("Open Automation Settings") { model.openAutomation() }.buttonStyle(QuietButton())
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Label("How Liris uses your data", systemImage: "info.circle").font(.system(size: 13, weight: .semibold))
                    Text("Liris reads track details and playback time from the YouTube Music tab in your selected browser. It sends the title, artist, album, and duration to LRCLIB to find lyrics. Album covers load from the URL supplied by your player. Lyrics are cached on this Mac.")
                    Text("The extension and direct YouTube Music connection use playback data. System audio recognition is optional, starts manually, and requires macOS capture permission. The microphone stays off. New lyrics require internet access. Firefox and third-party YouTube Music apps are currently unsupported.")
                    Text("To follow Spotify or Apple Music on your Mac, select the app as your source, click Connect, and grant Automation access. You can also search for lyrics or import an LRC file with the player disconnected.")
                }.font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(5)
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card, in: RoundedRectangle(cornerRadius: 13))
                HStack {
                    Text("Want a preview?").font(.system(size: 12)).foregroundStyle(Palette.muted)
                    Button("Start Visual Demo") { model.startDemo() }.buttonStyle(QuietButton())
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
