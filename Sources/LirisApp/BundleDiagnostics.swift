import AppKit
import SwiftUI
import LirisCore

/// Opt-in packaging diagnostics. Compiles scripts but never sends Apple Events or changes playback.
@MainActor
enum BundleDiagnostics {
    static func lyricsProbe(title: String, artist: String) -> Never {
        let model = AppModel()
        model.applyDiagnosticTrack(title: title, artist: artist)
        Task {
            for _ in 0..<25 {
                try? await Task.sleep(for: .seconds(1))
                if !model.loading {
                    let info: [String: Any] = ["recordID": model.record?.id ?? -1, "lineCount": model.lines.count,
                        "activeIndex": model.activeIndex ?? -1, "error": model.lyricsError ?? "", "confidence": model.lyricsResolution?.confidence.rawValue ?? "none"]
                    if let data = try? JSONSerialization.data(withJSONObject: info, options: [.sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
                    exit(model.record == nil ? 1 : 0)
                }
            }
            print("Lyrics lookup timed out"); exit(1)
        }
        RunLoop.main.run(); exit(1)
    }

    static func audioProbe() -> Never {
        _ = NSApplication.shared
        let audio = AudioRecognition(); audio.diagnosticOnly = !ProcessInfo.processInfo.arguments.contains("--probe-recognition")
        Task {
            do {
                try await audio.start()
                for _ in 0..<(audio.diagnosticOnly ? 15 : 35) {
                    try await Task.sleep(for: .seconds(1))
                    let data = try JSONSerialization.data(withJSONObject: audio.diagnostics, options: [.sortedKeys])
                    print(String(decoding: data, as: UTF8.self)); fflush(stdout)
                    if !audio.diagnosticOnly, let snapshot = audio.snapshot() {
                        print("MATCH: \(snapshot.title ?? "") / \(snapshot.artist ?? "") position=\(snapshot.position ?? 0)")
                        audio.stop(); exit(0)
                    }
                }
                let frames = audio.diagnostics["convertedFrames"] as? Int ?? 0
                audio.stop(); exit(frames > 0 ? 0 : 2)
            } catch { audio.stop(); fputs("Audio probe failed: \(error.localizedDescription)\n", stderr); exit(1) }
        }
        RunLoop.main.run(); exit(1)
    }

    /// Opt-in local playback read; does not query LRCLIB or issue playback commands.
    static func player() -> Never {
        let browser = Browser(rawValue: UserDefaults.standard.string(forKey: "browser") ?? "") ?? .brave
        Task {
            do {
                var monitor = PlayerTimeMonitor()
                var lastKey = ""
                let count = ProcessInfo.processInfo.arguments.contains("--watch") ? 12 : 1
                for index in 0..<count {
                guard let snapshot = try await MediaBridge.poll(source: .youtube, browser: browser) else {
                    print("No YouTube Music player found in \(browser.rawValue)"); exit(1)
                }
                if lastKey != snapshot.key { monitor = PlayerTimeMonitor(); lastKey = snapshot.key }
                let decision = monitor.evaluate(media: snapshot.mediaPosition, progress: snapshot.progressPosition,
                    visibleClock: snapshot.clockPosition, duration: snapshot.duration ?? 0, playing: snapshot.playing == true,
                    mediaPlaying: snapshot.mediaPlaying, uptime: ProcessInfo.processInfo.systemUptime)
                let values: [String: Any] = ["title": snapshot.title ?? "", "artist": snapshot.artist ?? "",
                    "position": decision.position ?? -1, "duration": snapshot.duration ?? 0,
                    "playing": snapshot.playing ?? false, "advertisement": snapshot.advertisement ?? false,
                    "positionSource": decision.source.rawValue, "health": decision.health.rawValue,
                    "mediaPosition": snapshot.mediaPosition ?? snapshot.position ?? 0,
                    "progressPosition": snapshot.progressPosition ?? snapshot.position ?? 0]
                let data = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
                print(String(decoding: data, as: UTF8.self))
                if index < count - 1 { try await Task.sleep(for: .milliseconds(250)) }
                }
                exit(0)
            } catch { fputs("FAIL: \(error.localizedDescription)\n", stderr); exit(1) }
        }
        RunLoop.main.run()
        exit(1)
    }

    static func preview(to path: String) -> Never {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let model = AppModel()
        model.startDemo(); model.togglePlayback()
        let arguments = ProcessInfo.processInfo.arguments
        var state = "demo"
        if let index = arguments.firstIndex(of: "--preview-state"), arguments.indices.contains(index + 1) { state = arguments[index + 1] }
        if state == "empty" { model.disconnect(clear: true) }
        if state == "help" { model.section = .help }
        if state == "appearance" { model.section = .appearance }
        if ["audio-active", "audio-suppressed", "overlay-audio"].contains(state) {
            model.previewAudioActivity(AudioCaptureActivity(phase: .active, suppressed: state == "audio-suppressed"))
        }
        if ["uncertain", "recovered", "waiting"].contains(state), let record = model.record {
            model.demo = false; model.connected = true
            let other = LyricsRecord(id: -3, trackName: record.trackName, artistName: record.artistName,
                albumName: "Alternatif demo", duration: record.duration, syncedLyrics: record.syncedLyrics)
            model.lyricsResolution = LyricsResolution(record: record, alternatives: [record, other],
                confidence: state == "uncertain" ? .uncertain : .compatible,
                reasons: state == "uncertain" ? ["Beberapa versi memiliki timing berbeda. Ketepatan terhadap vokal belum dapat dipastikan."] : [], comparedVersions: true)
            if state != "uncertain" {
                model.playerTimeHealth = state == "waiting" ? .waiting : .recovered
                model.playerTimeMessage = state == "waiting" ? "Waktu pemutar belum dapat dipercaya. Lirik dijeda sampai waktu pulih." : "Waktu tidak sejalan; otomatis mengikuti progress pemutar."
            }
        }
        let isOverlay = state == "overlay" || state == "overlay-audio"
        let root = isOverlay ? AnyView(OverlayView().environmentObject(model).preferredColorScheme(.dark))
            : AnyView(ContentView().environmentObject(model).preferredColorScheme(.dark))
        let view = NSHostingView(rootView: root)
        let frame = NSRect(x: 0, y: 0, width: isOverlay ? 800 : 1220, height: isOverlay ? 180 : 790)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        view.frame = frame
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        do {
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
            print("PASS: rendered native demo preview to \(path)")
            exit(0)
        } catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
    }

    static func run() -> Never {
        guard let url = Bundle.module.url(forResource: "youtube-music", withExtension: "js", subdirectory: "Resources"),
              let javascript = try? String(contentsOf: url, encoding: .utf8) else {
            fputs("FAIL: bundled YouTube Music probe is missing\n", stderr); exit(1)
        }
        var scripts = [(String, String)]()
        for browser in Browser.allCases where NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) != nil {
            scripts.append((browser.rawValue, MediaBridge.browserScript(browser, javascript: javascript)))
            let target = TrackSnapshot(available: true, windowID: 123, tabIndex: 1)
            scripts.append((browser.rawValue + " controls", MediaBridge.browserScript(browser, javascript: "'ok'", target: target)))
        }
        for source in [MusicSource.spotify, .music] where NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID!) != nil {
            scripts.append((source.rawValue, MediaBridge.playerScript(source)))
        }
        for (name, source) in scripts {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source), script.compileAndReturnError(&error) else {
                fputs("FAIL: \(name): \(error?.description ?? "compile failure")\n", stderr); exit(1)
            }
            print("PASS: \(name) script compiles")
        }
        print("PASS: packaged resource bundle (no playback or permissions changed)")
        exit(0)
    }
}
