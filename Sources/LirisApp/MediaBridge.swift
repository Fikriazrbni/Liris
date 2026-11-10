import AppKit
import Foundation

enum MusicSource: String, CaseIterable, Identifiable {
    case auto = "Auto", youtube = "YouTube Music", spotify = "Spotify", music = "Apple Music"
    var id: String { rawValue }
    var symbol: String { switch self { case .auto: "sparkles"; case .youtube: "play.rectangle.fill"; case .spotify: "waveform.circle.fill"; case .music: "music.note" } }
    var bundleID: String? { switch self { case .auto, .youtube: nil; case .spotify: "com.spotify.client"; case .music: "com.apple.Music" } }
}

enum Browser: String, CaseIterable, Identifiable {
    case chrome = "Google Chrome", brave = "Brave Browser", safari = "Safari", edge = "Microsoft Edge"
    var id: String { rawValue }
    var bundleID: String {
        switch self {
        case .chrome: "com.google.Chrome"
        case .brave: "com.brave.Browser"
        case .safari: "com.apple.Safari"
        case .edge: "com.microsoft.edgemac"
        }
    }
}

struct TrackSnapshot: Decodable, Equatable, Sendable {
    var available: Bool
    var id: String?
    var title: String?
    var artist: String?
    var album: String?
    var artwork: String?
    var position: Double?
    var duration: Double?
    var playing: Bool?
    var advertisement: Bool?
    var positionSource: String?
    var mediaPosition: Double?
    var progressPosition: Double?
    var clockPosition: Double?
    var mediaPlaying: Bool?
    var playbackRate: Double?
    var windowID: Int?
    var tabIndex: Int?

    var key: String { "\(id ?? "")|\(title ?? "")|\(artist ?? "")|\(album ?? "")" }
}

struct BridgeError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

/// Executes fixed scripts without a shell. The process has a bounded lifetime and is killed on cancellation.
enum ScriptRunner {
    static func run(_ source: String) async throws -> String {
        let task = Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "AppleScript", "-"]
            let input = Pipe(), output = Pipe(), errors = Pipe()
            process.standardInput = input; process.standardOutput = output; process.standardError = errors
            try process.run()
            defer { if process.isRunning { process.terminate() } }
            input.fileHandleForWriting.write(Data(source.utf8))
            try? input.fileHandleForWriting.close()
            let deadline = Date().addingTimeInterval(15)
            while process.isRunning {
                if Task.isCancelled || Date() >= deadline {
                    process.terminate()
                    throw BridgeError(message: "Koneksi ke aplikasi terlalu lama. Periksa dialog izin macOS, lalu hubungkan ulang.")
                }
                try await Task.sleep(for: .milliseconds(80))
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let error = errors.fileHandleForReading.readDataToEndOfFile()
            guard process.terminationStatus == 0 else {
                let details = String(decoding: error, as: UTF8.self)
                if details.contains("-1743") || details.localizedCaseInsensitiveContains("not authorized") {
                    throw BridgeError(message: "Izin Automation belum aktif. Buka System Settings → Privacy & Security → Automation, lalu izinkan Liris mengakses aplikasi musik/browser kamu.")
                }
                if details.localizedCaseInsensitiveContains("javascript") || details.contains("-1728") || details.contains("-10000") {
                    throw BridgeError(message: "Aktifkan ‘Allow JavaScript from Apple Events’ di browser. Lihat Panduan koneksi, lalu klik Hubungkan lagi.")
                }
                throw BridgeError(message: "Belum dapat membaca pemutar. Pastikan aplikasi terbuka dan lagu sudah dimuat. \(details.prefix(220))")
            }
            return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }
}

enum MediaBridge {
    static func quoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r") + "\""
    }

    static func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    static func poll(source: MusicSource, browser: Browser) async throws -> TrackSnapshot? {
        if source == .auto { return await AutoHub.shared.poll() }
        if source == .youtube {
            guard isRunning(browser.bundleID) else { return nil }
            let javascript = try youtubeProbe()
            let result = try await ScriptRunner.run(browserScript(browser, javascript: javascript))
            if result.isEmpty { return nil }
            let parts = result.split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else { throw BridgeError(message: "Respons browser tidak dikenali. Coba muat ulang YouTube Music.") }
            var snapshot = try JSONDecoder().decode(TrackSnapshot.self, from: Data(parts[2].utf8))
            snapshot.windowID = Int(parts[0]); snapshot.tabIndex = Int(parts[1])
            return snapshot.available ? snapshot : nil
        }
        guard let bundleID = source.bundleID, isRunning(bundleID) else { return nil }
        let result = try await ScriptRunner.run(playerScript(source))
        if result.isEmpty { return nil }
        // AppleScript returns a list of fields separated by ASCII unit separators.
        let fields = result.components(separatedBy: "\u{1f}")
        guard fields.count == 9 else { return nil }
        return TrackSnapshot(available: true, id: fields[0], title: fields[1], artist: fields[2],
                             album: fields[3], artwork: fields[4], position: Double(fields[5].replacingOccurrences(of: ",", with: ".")) ?? 0,
                             duration: Double(fields[6].replacingOccurrences(of: ",", with: ".")) ?? 0, playing: fields[7] == "playing", advertisement: false)
    }

    private static func youtubeProbe() throws -> String {
        guard let url = Bundle.module.url(forResource: "youtube-music", withExtension: "js", subdirectory: "Resources") else {
            throw BridgeError(message: "Skrip YouTube Music tidak ditemukan. Bangun ulang aplikasi.")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func browserScript(_ browser: Browser, javascript: String, target: TrackSnapshot? = nil) -> String {
        let execute = browser == .safari ? "do JavaScript \(quoted(javascript)) in t" : "execute t javascript \(quoted(javascript))"
        if let target, let windowID = target.windowID, let tabIndex = target.tabIndex {
            return """
            with timeout of 10 seconds
              tell application id "\(browser.bundleID)"
                set t to tab \(tabIndex) of window id \(windowID)
                if URL of t starts with "https://music.youtube.com/" then
                  return \(execute)
                end if
              end tell
            end timeout
            """
        }
        return """
        with timeout of 10 seconds
          tell application id "\(browser.bundleID)"
            set fallbackResult to ""
            repeat with w in windows
              set tabNumber to 0
              repeat with t in tabs of w
                set tabNumber to tabNumber + 1
                if URL of t starts with "https://music.youtube.com/" then
                  set payload to \(execute)
                  set packed to ((id of w) as text) & linefeed & (tabNumber as text) & linefeed & payload
                  if payload contains "\\\"available\\\":true" then
                    if payload contains "\\\"playing\\\":true" then return packed
                    if fallbackResult is "" then set fallbackResult to packed
                  end if
                end if
              end repeat
            end repeat
            return fallbackResult
          end tell
        end timeout
        """
    }

    static func playerScript(_ source: MusicSource) -> String {
        let duration = source == .spotify ? "((duration of t) / 1000)" : "(duration of t)"
        let artwork = source == .spotify ? "artwork url of t" : "\"\""
        let trackID = source == .spotify ? "id of t" : "persistent ID of t"
        return """
        with timeout of 10 seconds
          tell application id "\(source.bundleID!)"
            if player state is stopped then return ""
            set t to current track
            set xs to {\(trackID), name of t, artist of t, album of t, \(artwork), player position, \(duration), (player state as text), "end"}
            set AppleScript's text item delimiters to ASCII character 31
            return xs as text
          end tell
        end timeout
        """
    }

    static func control(source: MusicSource, browser: Browser, track: TrackSnapshot, position: Double? = nil) async throws {
        if source == .auto { try await AutoHub.shared.control(track: track, position: position); return }
        if source == .youtube {
            guard let id = track.id,
                  let encoded = String(data: try JSONSerialization.data(withJSONObject: id, options: [.fragmentsAllowed]), encoding: .utf8) else { return }
            let operation: String
            if let position {
                operation = "if (actual.positionSource !== 'media') return 'seek-in-browser'; v.currentTime = \(max(0, position));"
            } else {
                operation = "const button = document.querySelector('ytmusic-player-bar #play-pause-button'); if (!button) return 'missing'; button.click();"
            }
            let js = """
            (() => { const expected = \(encoded); const actual = JSON.parse(\(try youtubeProbe()));
            if (!actual.available || actual.id !== expected) return 'stale';
            const v = document.querySelector('ytmusic-player video') || document.querySelector('video');
            if (!v) return 'missing'; \(operation) return 'ok'; })()
            """
            let response = try await ScriptRunner.run(browserScript(browser, javascript: js, target: track))
            if response == "seek-in-browser" {
                throw BridgeError(message: "Untuk lagu ini, pindahkan posisi langsung di YouTube Music agar sinkronisasi tetap akurat.")
            }
            guard response == "ok" else { throw BridgeError(message: "Tab atau lagu berubah. Tunggu koneksi diperbarui, lalu coba lagi.") }
        } else {
            let operation = position.map { "set player position to \(max(0, $0))" } ?? "playpause"
            _ = try await ScriptRunner.run("with timeout of 10 seconds\ntell application id \"\(source.bundleID!)\" to \(operation)\nend timeout")
        }
    }
}
