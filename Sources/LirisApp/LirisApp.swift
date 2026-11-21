import SwiftUI
import AppKit

// Explicit wrapper alias also works with SDKs that introduce a same-named State macro.
typealias ViewState<Value> = SwiftUI.State<Value>

@main
struct LirisApp: App {
    @StateObject private var model = AppModel(connectOnLaunch: true)
    private let mainWindow = MainWindowController()

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
        MenuBarExtra {
            MenuBarView(openMainWindow: { mainWindow.show(model: model) }).environmentObject(model)
        } label: {
            if model.audioActivity.isEngaged {
                Label("Liris · Audio On", systemImage: "record.circle.fill")
            } else {
                Image(nsImage: LirisMark.image).accessibilityLabel("Liris")
            }
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Lyrics") {
                Button("Find Lyrics") { model.section = .search }.keyboardShortcut("f")
                Button("Import LRC File…") { model.importLRC() }.keyboardShortcut("o")
                Divider()
                Button(model.overlayVisible ? "Hide Overlay" : "Show Overlay") { model.toggleOverlay() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button(model.overlayLocked ? "Unlock Overlay" : "Lock Overlay") {
                    model.overlayLocked.toggle(); model.overlayController.updateLock()
                }
                Divider()
                Button("Advance lyrics by 0.2 seconds") { model.offset = min(10, model.offset + 0.2) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                Button("Delay lyrics by 0.2 seconds") { model.offset = max(-10, model.offset - 0.2) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            }
        }
    }
}

enum LirisMark {
    static let image: NSImage = {
        guard let url = Bundle.module.url(forResource: "lyric-mark", withExtension: "svg", subdirectory: "Resources"),
              let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "text.aligncenter", accessibilityDescription: "Liris")!
        }
        image.size = NSSize(width: 19.2, height: 12)
        image.isTemplate = true
        return image
    }()
}

@MainActor
final class MainWindowController {
    private var window: NSWindow?

    func show(model: AppModel) {
        let main: NSWindow
        if let window {
            main = window
        } else {
            main = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1220, height: 790),
                            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                            backing: .buffered, defer: false)
            main.title = "Liris"
            main.titleVisibility = .hidden
            main.titlebarAppearsTransparent = true
            main.isReleasedWhenClosed = false
            main.isRestorable = false
            main.tabbingMode = .disallowed
            main.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            main.contentView = NSHostingView(rootView: ContentView().environmentObject(model)
                .preferredColorScheme(.dark).frame(minWidth: 1040, minHeight: 700))
            main.contentMinSize = NSSize(width: 1040, height: 700)
            main.center()
            window = main
        }

        if main.isMiniaturized { main.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        main.makeKeyAndOrderFront(nil)
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    let openMainWindow: () -> Void

    var body: some View {
        Button("Open Liris", action: openMainWindow)
        Divider()
        Text(model.hasTrack ? model.title : "Waiting for music")
        Text(model.hasTrack ? model.currentText : model.status)
        ConnectionButton()
        Divider()
        Text(model.audioActivity.headline)
        if model.audioActivity.isEngaged {
            Button("Stop Audio") { model.stopAudioRecognition() }
                .disabled(model.audioActivity.phase == .stopping)
        } else {
            Button("Enable Audio") { model.enableAudioRecognition() }
                .disabled(!model.canStartAudioRecognition)
        }
        Divider()
        Button(model.overlayVisible ? "Hide Overlay" : "Show Overlay") { model.toggleOverlay() }
        if model.overlayVisible {
            Button(model.overlayLocked ? "Unlock Overlay" : "Lock Overlay") {
                model.overlayLocked.toggle(); model.overlayController.updateLock()
            }
        }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
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
