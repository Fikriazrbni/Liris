import SwiftUI
import AppKit

// Explicit wrapper alias also works with SDKs that introduce a same-named State macro.
typealias ViewState<Value> = SwiftUI.State<Value>

@main
struct LirisApp: App {
    @StateObject private var model = AppModel()

    init() {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--probe-lyrics"), args.count > index + 2 { BundleDiagnostics.lyricsProbe(title: args[index + 1], artist: args[index + 2]) }
        if ProcessInfo.processInfo.arguments.contains("--probe-audio") || ProcessInfo.processInfo.arguments.contains("--probe-recognition") { BundleDiagnostics.audioProbe() }
        if ProcessInfo.processInfo.arguments.contains("--diagnose-audio") {
            let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("id.local.liris/audio-status.json")
            if let data = try? Data(contentsOf: cache) { print(String(decoding: data, as: UTF8.self)); exit(0) }
            print("No audio diagnostics yet; connect Auto in the updated app."); exit(1)
        }
        if ProcessInfo.processInfo.arguments.contains("--verify-bundle") {
            BundleDiagnostics.run()
        }
        if ProcessInfo.processInfo.arguments.contains("--diagnose-player") {
            BundleDiagnostics.player()
        }
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--export-preview"),
           ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
            BundleDiagnostics.preview(to: ProcessInfo.processInfo.arguments[index + 1])
        }
        if let icon = Bundle.main.url(forResource: "LirisDock", withExtension: "icns") {
            NSApplication.shared.applicationIconImage = NSImage(contentsOf: icon)
        }
    }

    var body: some Scene {
        WindowGroup("Liris", id: "main") {
            ContentView().environmentObject(model)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1040, minHeight: 700)
        }
        .defaultSize(width: 1220, height: 790)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Lirik") {
                Button("Cari lirik") { model.section = .search }.keyboardShortcut("f")
                Button("Impor file LRC…") { model.importLRC() }.keyboardShortcut("o")
                Divider()
                Button(model.overlayVisible ? "Sembunyikan overlay" : "Tampilkan overlay") { model.toggleOverlay() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button(model.overlayLocked ? "Buka kunci overlay" : "Kunci overlay") {
                    model.overlayLocked.toggle(); model.overlayController.updateLock()
                }
                Divider()
                Button("Majukan lirik 0,2 detik") { model.offset = min(10, model.offset + 0.2) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                Button("Mundurkan lirik 0,2 detik") { model.offset = max(-10, model.offset - 0.2) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            }
        }
        MenuBarExtra {
            MenuBarView().environmentObject(model)
        } label: {
            Label(model.audioActivity.isEngaged ? "Liris · Audio aktif" : "Liris",
                  systemImage: model.audioActivity.isEngaged ? "record.circle.fill" : "quote.bubble.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Liris", systemImage: "waveform").font(.headline).foregroundStyle(model.accent)
            AudioCaptureStatusView(compact: true)
            Text(model.hasTrack ? model.title : "Menunggu musikmu").font(.headline).lineLimit(2)
            Text(model.hasTrack ? model.currentText : model.status).font(.callout).foregroundStyle(.secondary).lineLimit(3)
            Divider()
            Button(model.overlayVisible ? "Sembunyikan overlay" : "Tampilkan overlay") { model.toggleOverlay() }
            if model.overlayVisible {
                Button(model.overlayLocked ? "Buka kunci overlay" : "Kunci overlay") {
                    model.overlayLocked.toggle(); model.overlayController.updateLock()
                }
            }
            Button("Buka Liris") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
            Button("Keluar dari Liris") { NSApp.terminate(nil) }
        }.padding(20).frame(width: 300).buttonStyle(.plain)
    }
}

extension AppModel {
    var accent: Color {
        switch accentName {
        case "Lavender": Color(red: 0.73, green: 0.65, blue: 1)
        case "Peach": Color(red: 1, green: 0.72, blue: 0.53)
        default: Color(red: 0.79, green: 0.94, blue: 0.48)
        }
    }
}

enum Palette {
    static let background = Color(red: 0.055, green: 0.063, blue: 0.067)
    static let sidebar = Color(red: 0.075, green: 0.084, blue: 0.087)
    static let card = Color(red: 0.10, green: 0.112, blue: 0.114)
    static let muted = Color(red: 0.55, green: 0.59, blue: 0.57)
    static let line = Color.white.opacity(0.07)
}

struct AccentButton: ButtonStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(Color.black.opacity(0.85)).background(color.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.055), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.line))
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View { Text(text).font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(Palette.muted) }
}
