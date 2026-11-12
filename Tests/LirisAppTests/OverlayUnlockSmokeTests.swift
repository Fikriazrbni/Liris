import AppKit
import Testing
@testable import LirisApp

@MainActor
@Test func lockedOverlayKeepsItsUnlockButton() throws {
    _ = NSApplication.shared
    let model = AppModel()
    let controller = model.overlayController
    defer { controller.hide() }

    model.overlayLocked = true
    controller.show()
    let panel = try #require(NSApp.windows.first { $0.title == "Liris Overlay" })
    let child = try #require(panel.childWindows?.first)
    let button = try #require(child.contentView as? NSButton)
    #expect(panel.ignoresMouseEvents)
    #expect(child.isVisible)
    #expect(!child.ignoresMouseEvents)
    #expect(panel.frame.contains(child.frame))

    controller.hide()
    #expect(!child.isVisible)
    controller.show()
    #expect(child.parent === panel)
    #expect(child.isVisible)

    button.performClick(nil)
    #expect(!model.overlayLocked)
    #expect(!panel.ignoresMouseEvents)
    #expect(!child.isVisible)
}
