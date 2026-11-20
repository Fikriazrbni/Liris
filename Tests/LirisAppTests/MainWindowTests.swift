import AppKit
import Testing
@testable import LirisApp

@Suite(.serialized) @MainActor
struct MainWindowTests {
    private var mainWindows: [NSWindow] { NSApp.windows.filter { $0.title == "Liris" } }

    @Test func closingAndReopeningKeepsWindowAndConnection() throws {
        _ = NSApplication.shared
        let model = AppModel(connectOnLaunch: true, pollPlayer: { _, _ in nil })
        defer { model.disconnect() }
        let controller = MainWindowController()
        #expect(mainWindows.isEmpty)
        controller.show(model: model)
        let window = try #require(mainWindows.first)
        defer { window.close() }
        controller.show(model: model)
        #expect(mainWindows == [window])
        window.close()
        #expect(!window.isVisible)
        #expect(model.connected)
        controller.show(model: model)
        #expect(window.isVisible)
        #expect(mainWindows == [window])
    }

    // AppKit delegates minimization to the Dock in the current GUI login session.
    @Test(.enabled(if: !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").isEmpty))
    func openRestoresMinimizedAgentWindow() async throws {
        let app = NSApplication.shared
        let previousPolicy = app.activationPolicy()
        app.setActivationPolicy(.accessory)
        defer { app.setActivationPolicy(previousPolicy) }
        app.finishLaunching()
        let model = AppModel()
        let controller = MainWindowController()
        controller.show(model: model)
        let window = try #require(mainWindows.first)
        defer { window.close() }
        window.miniaturize(nil)
        for _ in 0..<30 where !window.isMiniaturized {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(window.isMiniaturized)
        controller.show(model: model)
        for _ in 0..<30 where window.isMiniaturized {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(!window.isMiniaturized)
        #expect(window.isVisible)
        #expect(mainWindows == [window])
        #expect(app.activationPolicy() == .accessory)
    }
}
