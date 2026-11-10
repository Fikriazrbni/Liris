import AppKit
import Combine
import LirisCore
import UniformTypeIdentifiers

enum Section: String, CaseIterable {
    case listening = "Sedang diputar", search = "Cari lirik", appearance = "Tampilan", help = "Panduan koneksi"
    var symbol: String {
        switch self { case .listening: "waveform"; case .search: "magnifyingglass"; case .appearance: "slider.horizontal.3"; case .help: "questionmark.circle" }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var section: Section = .listening
    @Published var source: MusicSource { didSet { UserDefaults.standard.set(source.rawValue, forKey: "source"); sourceChanged() } }
    @Published var browser: Browser { didSet { UserDefaults.standard.set(browser.rawValue, forKey: "browser"); sourceChanged() } }
    @Published var connected = false
    @Published var demo = false
    @Published private(set) var audioActivity = AudioCaptureActivity()
    @Published var snapshot: TrackSnapshot?
    @Published var record: LyricsRecord? { didSet { lines = record?.lines ?? [] } }
    private(set) var lines: [LyricLine] = []
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var playing = false
    @Published var loading = false
    @Published var status = "Siap menemani musikmu"
    @Published var connectionError: String?
    @Published var lyricsError: String?
    @Published var lyricsResolution: LyricsResolution?
    @Published var playerTimeHealth: PlayerTimeHealth = .consistent
    @Published var playerTimeMessage = ""
    @Published private(set) var effectiveTimeSource: PlayerTimeSource = .media
    @Published var searchQuery = ""
    @Published var searchResults: [LyricsRecord] = []
    @Published var searching = false
    @Published var searchError: String?
    @Published var didSearch = false
    @Published var offset: Double = 0 {
        didSet {
            guard let activeSignature, offset.isFinite else { return }
            var saved = UserDefaults.standard.dictionary(forKey: "trackOffsets") ?? [:]
            if abs(offset) < 0.001 {
                guard saved.removeValue(forKey: activeSignature.key) != nil else { return }
            } else { saved[activeSignature.key] = offset }
            UserDefaults.standard.set(saved, forKey: "trackOffsets")
        }
    }
    @Published var overlayVisible = false
    @Published var overlayLocked = false
    @Published var fontSize: Double { didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") } }
    @Published var opacity: Double { didSet { UserDefaults.standard.set(opacity, forKey: "opacity") } }
    @Published var accentName: String { didSet { UserDefaults.standard.set(accentName, forKey: "accent") } }

    private var pollTask: Task<Void, Never>?
    private let audio: any AudioCaptureControlling
    private let pollPlayer: @MainActor (MusicSource, Browser) async throws -> TrackSnapshot?
    private var audioActivityPreview: AudioCaptureActivity?
    private var audioStartTask: Task<Void, Never>?
    private var audioRequest = UUID()
    private var lyricTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var ticker: AnyCancellable?
    private var clock = PlaybackClock()
    private var timeMonitor = PlayerTimeMonitor()
    private var activeSignature: TrackSignature?
    private var generation = UUID()
    private var searchGeneration = UUID()
    private var lyricGeneration = UUID()
    private var selectedTrackKey = ""
    private var selectedDuration: Double = 0
    private let client: LyricsClient
    lazy var overlayController = OverlayController(model: self)

    var activeIndex: Int? { LRCParser.activeIndex(in: lines, at: position, adjustment: offset) }
    var title: String { snapshot?.title ?? record?.trackName ?? "Musik menyala.\nLirik ikut bercerita." }
    var artist: String { snapshot?.artist ?? record?.artistName ?? "Hubungkan YouTube Music untuk mulai mendengarkan." }
    var hasTrack: Bool { snapshot != nil || record != nil }
    var canSeek: Bool { hasTrack && snapshot?.positionSource != "recognition" && snapshot?.positionSource != "extension-progress" && !(connected && source == .youtube && effectiveTimeSource != .media) }
    var syncNeedsAttention: Bool { playerTimeHealth == .waiting || playerTimeHealth == .limited || lyricsResolution?.confidence != .compatible }
    var syncHeadline: String {
        if playerTimeHealth == .waiting { return "Menunggu waktu pemutar pulih" }
        if !connected { return "Timer manual · belum mengikuti pemutar" }
        if loading { return "Memeriksa kecocokan lirik…" }
        if lyricsResolution?.confidence == .incompatible { return "Versi lirik belum cocok" }
        if lyricsResolution?.confidence == .uncertain { return "Timing lirik perlu diperiksa" }
        if playerTimeHealth == .recovered { return "Waktu dikoreksi otomatis" }
        if playerTimeHealth == .limited { return "Sumber waktu terbatas" }
        return lyricsResolution?.savedChoice == true ? "Memakai pilihan tersimpan" : "Metadata dan batas waktu cocok"
    }
    var syncExplanation: String {
        if playerTimeHealth == .waiting { return playerTimeMessage }
        if !connected { return "Hubungkan pemutar atau mulai timer bersamaan dengan musikmu." }
        if let issue = lyricsResolution?.reasons.first { return issue }
        if playerTimeHealth == .recovered || playerTimeHealth == .limited { return playerTimeMessage }
        if lyricsResolution?.savedChoice == true { return "Pilihan versi dan koreksi waktumu diingat untuk lagu ini." }
        return "Kecocokan judul, artis, versi, durasi, dan timestamp diperiksa. Ketepatan vokal belum diverifikasi."
    }
    var currentText: String {
        if connected && playerTimeHealth == .waiting { return "Menunggu waktu pemutar pulih…" }
        guard let index = activeIndex else { return hasTrack ? "Menunggu bait pertama…" : "Musikmu, kata demi kata." }
        return lines[index].text.isEmpty ? "♪" : lines[index].text
    }
    var nextText: String {
        if connected && playerTimeHealth == .waiting { return "" }
        let index = (activeIndex ?? -1) + 1
        guard lines.indices.contains(index) else { return "" }
        return lines[index].text
    }

    init(audio: (any AudioCaptureControlling)? = nil,
         pollPlayer: @escaping @MainActor (MusicSource, Browser) async throws -> TrackSnapshot? = { try await MediaBridge.poll(source: $0, browser: $1) }) {
        self.audio = audio ?? AutoHub.shared.audio
        self.pollPlayer = pollPlayer
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "autoAudioEnabled") // Migrate the old opt-in; each session now requires a click.
        source = MusicSource(rawValue: defaults.string(forKey: "source") ?? "") ?? .youtube
        browser = Browser(rawValue: defaults.string(forKey: "browser") ?? "") ?? .brave
        fontSize = defaults.object(forKey: "fontSize") == nil ? 28 : defaults.double(forKey: "fontSize")
        opacity = defaults.object(forKey: "opacity") == nil ? 0.88 : defaults.double(forKey: "opacity")
        accentName = defaults.string(forKey: "accent") ?? "Lime"
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("id.local.liris/lyrics", isDirectory: true)
        client = LyricsClient(cacheDirectory: cache)
        ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().sink { [weak self] _ in self?.tick() }
        if ProcessInfo.processInfo.arguments.contains("--demo") { startDemo() }
    }

    private func tick() {
        refreshAudioActivity()
        guard playing else { return }
        // Monotonic interpolation follows actual player snapshots; no accumulating timer drift.
        position = min(duration > 0 ? duration : .greatestFiniteMagnitude,
                       clock.position(at: ProcessInfo.processInfo.systemUptime))
        if duration > 0 && position >= duration && (!connected || demo) {
            anchor(position, playing: false)
        }
    }

    private func anchor(_ position: Double, playing: Bool) {
        self.position = max(0, position.isFinite ? position : 0)
        clock = PlaybackClock()
        clock.update(position: self.position, playing: playing, uptime: ProcessInfo.processInfo.systemUptime)
        self.playing = playing
    }

    private func sourceChanged() { disconnect(clear: true) }

    func connect() {
        disconnect(clear: true)
        connected = true; demo = false; connectionError = nil
        let token = UUID(); generation = token
        let selectedSource = source, selectedBrowser = browser
        let pollPlayer = self.pollPlayer
        status = "Menghubungkan \(selectedSource.rawValue)…"
        pollTask = Task { [weak self] in
            var interval = Duration.seconds(1)
            while !Task.isCancelled {
                do {
                    let track = try await pollPlayer(selectedSource, selectedBrowser)
                    guard let self, self.generation == token, !Task.isCancelled else { return }
                    self.connectionError = nil
                    if let track {
                        self.receive(track)
                        interval = self.effectiveTimeSource != .media ? .milliseconds(250) : .seconds(1)
                    }
                    else {
                        self.clearTrack()
                        self.status = selectedSource == .auto ? AutoHub.shared.route : selectedSource == .youtube ? "Buka music.youtube.com di \(selectedBrowser.rawValue), lalu putar lagu." : "Buka \(selectedSource.rawValue), lalu putar lagu."
                    }
                } catch {
                    guard let self, self.generation == token, !Task.isCancelled else { return }
                    self.connectionError = error.localizedDescription
                    self.status = "Koneksi perlu diperiksa"
                    self.connected = false; self.anchor(self.position, playing: false)
                    return // Avoid repeating permission dialogs or failed requests.
                }
                if let self, self.source == .auto {
                    AutoHub.shared.diagnosticExtras = ["detectedTitle": self.snapshot?.title ?? "", "detectedArtist": self.snapshot?.artist ?? "",
                        "lyricLines": self.lines.count, "lyricsError": self.lyricsError ?? "", "uiStatus": self.status, "connected": self.connected]
                }
                try? await Task.sleep(for: interval)
            }
        }
    }

    func disconnect(clear: Bool = false) {
        stopAudioRecognition()
        AutoHub.shared.stop()
        generation = UUID(); pollTask?.cancel(); pollTask = nil
        connected = false; playing = false; demo = false
        connectionError = nil; status = "Siap menemani musikmu"
        if clear { clearTrack() }
    }

    private func clearTrack() {
        lyricTask?.cancel(); lyricGeneration = UUID(); loading = false
        activeSignature = nil; lyricsResolution = nil
        timeMonitor = PlayerTimeMonitor(); playerTimeHealth = .consistent; playerTimeMessage = ""; effectiveTimeSource = .media
        snapshot = nil; record = nil; selectedTrackKey = ""; selectedDuration = 0; lyricsError = nil
        anchor(0, playing: false); duration = 0; offset = 0
    }

    private func receive(_ track: TrackSnapshot) {
        if track.advertisement == true {
            clearTrack(); status = "Iklan sedang diputar. Lirik akan kembali setelah lagu dimulai."
            return
        }
        let newTrack = snapshot?.key != track.key
        if newTrack { clock = PlaybackClock(); timeMonitor = PlayerTimeMonitor() }
        let measuredDuration = max(0, track.duration ?? 0)
        duration = track.positionSource == "recognition" && measuredDuration == 0 ? (newTrack ? 0 : record?.duration ?? 0) : measuredDuration
        snapshot = track
        let now = ProcessInfo.processInfo.systemUptime
        let decision = (source == .youtube || (source == .auto && track.positionSource?.hasPrefix("extension") == true)) ? timeMonitor.evaluate(media: track.mediaPosition,
            progress: track.progressPosition, visibleClock: track.clockPosition, duration: duration,
            playing: track.playing == true, mediaPlaying: track.mediaPlaying, uptime: now)
            : PlayerTimeDecision(position: track.position ?? 0, source: .media, health: track.positionSource == "recognition" ? .limited : .consistent,
                reason: track.positionSource == "recognition" ? "Posisi diperkirakan dari cuplikan audio dan akan dikalibrasi ulang." : "Waktu pemutar tersedia.")
        playerTimeHealth = decision.health; playerTimeMessage = decision.reason; effectiveTimeSource = decision.source
        clock.update(position: decision.position ?? position, playing: decision.position != nil && track.playing == true,
                     uptime: now, wholeSeconds: decision.wholeSeconds,
                     playbackRate: track.playbackRate ?? 1)
        position = clock.position(at: now)
        playing = decision.position != nil && track.playing == true
        status = source == .auto ? AutoHub.shared.route : decision.health == .waiting ? "Menunggu waktu pemutar pulih" : playing ? "Mengikuti \(source.rawValue)" : "Pemutaran dijeda"
        let changedTrack = selectedTrackKey != track.key
        let resolvedDuration = measuredDuration > 0 && abs(measuredDuration - selectedDuration) > 2
        guard changedTrack || resolvedDuration else { return }
        selectedTrackKey = track.key; selectedDuration = measuredDuration; record = nil; lyricsResolution = nil
        let signature = TrackSignature(title: track.title ?? "", artist: track.artist ?? "", album: track.album ?? "", duration: measuredDuration)
        activeSignature = signature
        if changedTrack || resolvedDuration {
            let saved = UserDefaults.standard.dictionary(forKey: "trackOffsets")?[signature.key] as? Double ?? 0
            offset = saved.isFinite ? min(10, max(-10, saved)) : 0
        }
        loadLyrics()
    }

    func loadLyrics(forceRefresh: Bool = false) {
        lyricTask?.cancel(); lyricGeneration = UUID()
        guard let track = snapshot, let signature = activeSignature else { return }
        let token = lyricGeneration, key = track.key
        loading = true; lyricsError = nil
        lyricTask = Task {
            defer { if lyricGeneration == token { loading = false } }
            do {
                let result = try await client.resolve(signature, forceRefresh: forceRefresh)
                guard !Task.isCancelled, lyricGeneration == token, snapshot?.key == key else { return }
                record = result.record; lyricsResolution = result
                if duration <= 0, let length = result.record?.duration { duration = length }
                if result.record == nil { lyricsError = result.reasons.first ?? "Lirik belum ditemukan. Coba cari judul dan artisnya, atau impor file .lrc." }
            } catch {
                guard !Task.isCancelled, lyricGeneration == token else { return }
                lyricsError = "Tidak dapat mengambil lirik. \(error.localizedDescription)"
            }
        }
    }

    func search() {
        searchTask?.cancel(); searchGeneration = UUID()
        let token = searchGeneration, query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { searchResults = []; didSearch = false; searching = false; return }
        searching = true; searchError = nil; didSearch = true
        searchTask = Task {
            defer { if searchGeneration == token { searching = false } }
            do {
                let results = try await client.search(query)
                guard !Task.isCancelled, searchGeneration == token else { return }
                searchResults = results.sorted { $0.hasSync && !$1.hasSync }
            } catch {
                guard !Task.isCancelled, searchGeneration == token else { return }
                searchError = error.localizedDescription; searchResults = []
            }
        }
    }

    func select(_ result: LyricsRecord) {
        lyricTask?.cancel(); lyricGeneration = UUID(); loading = false
        demo = false
        record = result; offset = 0; lyricsError = nil; section = .listening
        if let signature = activeSignature {
            let assessment = SyncAssessment.assess(result, for: signature)
            lyricsResolution = LyricsResolution(record: result,
                alternatives: lyricsResolution?.alternatives ?? [result], confidence: assessment.confidence,
                reasons: assessment.reasons, comparedVersions: lyricsResolution?.comparedVersions ?? false,
                savedChoice: assessment.confidence != .incompatible)
            Task { await client.rememberChoice(result, for: signature) }
        }
        if snapshot == nil { duration = result.duration; anchor(0, playing: false); status = "Lirik manual · mulai timer bersama musikmu" }
    }

    func useAutomaticLyrics() {
        guard let signature = activeSignature else { return }
        Task {
            await client.clearChoice(for: signature)
            guard activeSignature == signature else { return }
            offset = 0
            loadLyrics()
        }
    }

    func importLRC() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "lrc") ?? .plainText, .plainText]
        panel.allowsMultipleSelection = false; panel.message = "Pilih lirik bertimestamp (.lrc) untuk lagu yang sedang diputar."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= 2_000_000 else { throw BridgeError(message: "File terlalu besar. Pilih file LRC di bawah 2 MB.") }
            guard let text = String(data: data, encoding: .utf8), !LRCParser.parse(text).isEmpty else {
                throw BridgeError(message: "File harus berupa LRC UTF-8 dengan timestamp, misalnya [00:12.50].")
            }
            select(LyricsRecord(id: -2, trackName: snapshot?.title ?? url.deletingPathExtension().lastPathComponent,
                                artistName: snapshot?.artist ?? "File lokal", duration: duration > 0 ? duration : (LRCParser.parse(text).last?.time ?? 0) + 10,
                                syncedLyrics: text))
        } catch { lyricsError = error.localizedDescription }
    }

    func togglePlayback() {
        guard hasTrack else { return }
        if connected, let snapshot {
            let token = generation, selectedSource = source, selectedBrowser = browser
            Task {
                do { try await MediaBridge.control(source: selectedSource, browser: selectedBrowser, track: snapshot) }
                catch { if token == generation { connectionError = error.localizedDescription } }
            }
        } else { anchor(position, playing: !playing) }
    }

    func seek(_ value: Double) {
        guard value.isFinite, canSeek else { return }
        let value = min(max(0, value), max(duration, 0))
        if connected, let snapshot {
            let token = generation, selectedSource = source, selectedBrowser = browser
            Task {
                do {
                    try await MediaBridge.control(source: selectedSource, browser: selectedBrowser, track: snapshot, position: value)
                    if token == generation { anchor(value, playing: playing) }
                } catch { if token == generation { connectionError = error.localizedDescription } }
            }
        } else { anchor(value, playing: playing) }
    }

    func toggleOverlay() {
        if overlayVisible { overlayController.hide() } else { overlayController.show() }
    }

    func startDemo() {
        disconnect(clear: true); demo = true
        let text = """
        [00:00.00]Ada nada di antara kita
        [00:05.00]Mengalir pelan menemani senja
        [00:10.00]Biarkan dunia berputar sejenak
        [00:15.00]Kita dengarkan cerita yang sama
        [00:21.00]Setiap kata menemukan nadanya
        [00:27.00]Di ruang kecil tempat kita pulang
        [00:33.00]Tak perlu terburu mengejar waktu
        [00:39.00]Lagu ini masih milik kita
        [00:45.00]
        """
        record = LyricsRecord(id: -1, trackName: "Ruang Senja", artistName: "Liris Studio", albumName: "Sebuah demonstrasi", duration: 50, syncedLyrics: text)
        duration = 50; anchor(16, playing: true)
        status = "Demo visual · teks orisinal, tanpa audio"
        section = .listening
    }


    func applyDiagnosticTrack(title: String, artist: String) {
        source = .auto; connected = true
        receive(TrackSnapshot(available: true, id: "diagnostic", title: title, artist: artist, position: 30, duration: 0, playing: true, positionSource: "recognition"))
    }
    func openAutoExtension() {
        if let folder = Bundle.main.resourceURL?.appendingPathComponent("AutoExtension") { NSWorkspace.shared.open(folder) }
        let url = URL(string: "brave://extensions")!
        if let brave = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.brave.Browser") {
            NSWorkspace.shared.open([url], withApplicationAt: brave, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    var canStartAudioRecognition: Bool {
        connected && source == .auto && audio.configured && !audioActivity.isEngaged && audioStartTask == nil
    }
    func refreshAudioActivity() {
        let latest = audioActivityPreview ?? audio.activity
        if latest != audioActivity { audioActivity = latest }
    }
    func enableAudioRecognition() {
        guard canStartAudioRecognition else { return }
        let token = generation, request = UUID()
        audioRequest = request
        audioActivity = AudioCaptureActivity(phase: .starting)
        audioStartTask = Task {
            defer {
                if audioRequest == request { audioStartTask = nil; refreshAudioActivity() }
            }
            guard audioRequest == request, generation == token, connected, source == .auto, !Task.isCancelled else { return }
            do {
                try await audio.start()
                guard audioRequest == request, generation == token, !Task.isCancelled else { return }
                refreshAudioActivity()
                if audioActivity.phase == .active { status = "Mendengarkan audio sistem lewat ShazamIO…" }
            } catch {
                guard audioRequest == request, generation == token, !Task.isCancelled else { return }
                audio.reportStartFailure(error); connectionError = error.localizedDescription
            }
        }
    }
    func stopAudioRecognition() {
        audioRequest = UUID(); audioStartTask?.cancel(); audioStartTask = nil
        audio.stop(); refreshAudioActivity()
        if snapshot?.positionSource == "recognition" { clearTrack() }
        status = "Pengenalan audio dimatikan"
    }

    // Rendering previews never start capture or a worker.
    func previewAudioActivity(_ activity: AudioCaptureActivity) { audioActivityPreview = activity; refreshAudioActivity() }

    func openYouTube() { NSWorkspace.shared.open(URL(string: "https://music.youtube.com")!) }
    func openAudioPrivacy() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!) }
    func openAutomation() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!) }
}
