import AppKit
import SwiftUI

private enum OverlayLayout {
    static let outerPadding: CGFloat = 4
    static let horizontalPadding: CGFloat = 25
    static let verticalPadding: CGFloat = 17
    static let lockSize = NSSize(width: 24, height: 20)
}

@MainActor
final class OverlayController: NSObject, NSWindowDelegate {
    private weak var model: AppModel?
    private var panel: NSPanel?
    private var unlockPanel: NSPanel?
    init(model: AppModel) { self.model = model }

    func show() {
        guard let model else { return }
        if panel == nil {
            let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let width = min(800, visible.width - 80)
            let saved = UserDefaults.standard.string(forKey: "overlayFrame")
            var frame = NSRect(x: visible.midX - width / 2, y: visible.minY + 60, width: width, height: 180)
            if let saved {
                let rect = NSRectFromString(saved)
                if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(rect) }) { frame = rect }
            }
            let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
            panel.title = "Liris Overlay"
            panel.isFloatingPanel = true; panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false; panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.minSize = NSSize(width: 480, height: 150); panel.maxSize = NSSize(width: 1200, height: 400)
            let hostingView = NSHostingView(rootView: OverlayView(interactive: true).environmentObject(model))
            hostingView.sizingOptions = []
            panel.contentView = hostingView
            panel.delegate = self
            self.panel = panel
        }
        panel?.orderFrontRegardless()
        model.overlayVisible = true
        updateLock()
    }

    func hide() {
        unlockPanel?.orderOut(nil)
        panel?.orderOut(nil)
        model?.overlayVisible = false
    }

    func updateLock() {
        guard let panel, let model else { return }
        panel.ignoresMouseEvents = model.overlayLocked
        guard model.overlayLocked, panel.isVisible else {
            unlockPanel?.orderOut(nil)
            return
        }

        // Only the lock button intercepts clicks while the lyrics panel is click-through.
        let control = unlockPanel ?? makeUnlockPanel()
        unlockPanel = control
        positionUnlockPanel()
        if control.parent !== panel { panel.addChildWindow(control, ordered: .above) }
        control.orderFrontRegardless()
    }

    private func makeUnlockPanel() -> NSPanel {
        let control = NSPanel(contentRect: NSRect(origin: .zero, size: OverlayLayout.lockSize),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        control.title = "Buka kunci overlay"
        control.level = .floating
        control.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        control.isOpaque = false
        control.backgroundColor = .clear
        control.hasShadow = false
        control.hidesOnDeactivate = false
        control.isReleasedWhenClosed = false
        control.isExcludedFromWindowsMenu = true

        let button = OverlayUnlockButton(frame: NSRect(origin: .zero, size: OverlayLayout.lockSize))
        button.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Buka kunci overlay")
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.contentTintColor = .white
        button.toolTip = "Buka kunci overlay"
        button.setAccessibilityLabel("Buka kunci overlay")
        button.target = self
        button.action = #selector(unlockOverlay)
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        button.layer?.cornerRadius = 5
        control.contentView = button
        return control
    }

    private func positionUnlockPanel() {
        guard let panel, let unlockPanel else { return }
        let x = panel.frame.maxX - OverlayLayout.outerPadding - OverlayLayout.horizontalPadding - OverlayLayout.lockSize.width
        let y = panel.frame.maxY - OverlayLayout.outerPadding - OverlayLayout.verticalPadding - OverlayLayout.lockSize.height
        unlockPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func unlockOverlay() {
        model?.overlayLocked = false
        updateLock()
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) {
        saveFrame()
        positionUnlockPanel()
    }
    private func saveFrame() {
        if let panel { UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "overlayFrame") }
    }
}

private final class OverlayUnlockButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct OverlayView: View {
    @EnvironmentObject private var model: AppModel
    @ViewState private var hovered = false
    var interactive = false

    private var trackLabel: String {
        guard model.hasTrack else { return "Menunggu musikmu" }
        let artist = [model.snapshot?.artist, model.record?.artistName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let artist else { return model.title }
        return "\(model.title) · \(artist)"
    }

    private var activeLyric: String {
        guard model.record?.hasSync == false else { return model.currentText }
        return model.record?.instrumental == true ? "♪ Instrumental" : "Lirik ini belum memiliki timestamp"
    }

    private func lyricRows(fontSize: CGFloat, activeLineLimit: Int) -> some View {
        VStack(spacing: 4) {
            nearbyLyric(model.previousText, fontSize: fontSize)
            Text(activeLyric)
                .font(.system(size: fontSize, weight: .semibold)).tracking(-0.5)
                .foregroundStyle(model.accent)
                .lineLimit(activeLineLimit)
                .minimumScaleFactor(0.65)
            nearbyLyric(model.nextText, fontSize: fontSize)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func nearbyLyric(_ text: String, fontSize: CGFloat) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: max(13, fontSize * 0.55), weight: .medium))
            .foregroundStyle(.white.opacity(0.43))
            .lineLimit(1)
            .accessibilityHidden(text.isEmpty)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "waveform").foregroundStyle(model.accent)
                Text("LIRIS").tracking(2)
                Text("/").foregroundStyle(.white.opacity(0.2))
                Text(trackLabel).lineLimit(1).help(trackLabel)
                if model.hasTrack && !model.demo {
                    Image(systemName: model.syncNeedsAttention ? "exclamationmark.circle" : "checkmark.shield")
                        .foregroundStyle(model.syncNeedsAttention ? Color.orange : model.accent)
                        .help(model.syncHeadline + ". " + model.syncExplanation)
                }
                if model.demo { Text("· DEMO TANPA AUDIO").foregroundStyle(model.accent) }
                Spacer(minLength: 5)
                if model.audioActivity.isEngaged {
                    HStack(spacing: 4) {
                        Image(systemName: "record.circle.fill")
                        Text(model.audioActivity.phase == .stopping ? "MENGHENTIKAN" : "AUDIO AKTIF")
                    }.foregroundStyle(.orange).help(model.audioActivity.headline + ". " + model.audioActivity.detail)
                    if !model.overlayLocked {
                        Button("Matikan") { model.stopAudioRecognition() }
                            .buttonStyle(.plain).foregroundStyle(.orange)
                            .disabled(model.audioActivity.phase == .stopping)
                            .accessibilityLabel("Matikan pengenalan audio sistem")
                    }
                }
                if interactive && !model.overlayLocked {
                    OverlayHandle(mode: .move)
                        .frame(width: 32, height: 20)
                        .overlay { Image(systemName: "line.3.horizontal").allowsHitTesting(false) }
                        .accessibilityLabel("Geser overlay")
                }
                if (interactive || hovered) && !model.overlayLocked {
                    Button { model.toggleOverlay() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).padding(.leading, 9).help("Tutup overlay")
                    Button { model.overlayLocked = true; model.overlayController.updateLock() } label: {
                        Image(systemName: "lock.open")
                            .frame(width: OverlayLayout.lockSize.width, height: OverlayLayout.lockSize.height)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).help("Kunci overlay")
                } else if interactive && model.overlayLocked {
                    Color.clear.frame(width: OverlayLayout.lockSize.width, height: OverlayLayout.lockSize.height)
                        .accessibilityHidden(true)
                } else if model.overlayLocked || !interactive {
                    Image(systemName: model.overlayLocked ? "lock.fill" : "hand.draw").opacity(0.5)
                }
            }.frame(maxWidth: .infinity)
                .font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.4))
            Spacer(minLength: 0)
            ViewThatFits(in: .vertical) {
                lyricRows(fontSize: model.fontSize, activeLineLimit: 2)
                    .fixedSize(horizontal: false, vertical: true)
                lyricRows(fontSize: min(model.fontSize, 30), activeLineLimit: 1)
                    .fixedSize(horizontal: false, vertical: true)
                lyricRows(fontSize: min(model.fontSize, 22), activeLineLimit: 1)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, OverlayLayout.horizontalPadding).padding(.vertical, OverlayLayout.verticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background.opacity(model.opacity), in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(.white.opacity(0.1)))
            .overlay(alignment: .bottomTrailing) {
                if interactive && !model.overlayLocked {
                    OverlayHandle(mode: .resize)
                        .frame(width: 26, height: 26)
                        .overlay {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.65))
                                .allowsHitTesting(false)
                        }
                        .padding(4)
                        .accessibilityLabel("Ubah ukuran overlay")
                }
            }
            .padding(OverlayLayout.outerPadding).onHover { hovered = $0 }
    }
}

private struct OverlayHandle: NSViewRepresentable {
    enum Mode { case move, resize }
    let mode: Mode

    func makeNSView(context: Context) -> HandleView { HandleView(mode: mode) }
    func updateNSView(_ view: HandleView, context: Context) {}

    final class HandleView: NSView {
        private let mode: Mode
        private var start: (pointer: NSPoint, frame: NSRect)?

        init(mode: Mode) {
            self.mode = mode
            super.init(frame: .zero)
            toolTip = mode == .move ? "Tarik untuk memindahkan overlay" : "Tarik untuk mengubah ukuran overlay"
        }

        required init?(coder: NSCoder) { nil }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: mode == .move ? .openHand : .crosshair)
        }

        override func mouseDown(with event: NSEvent) {
            guard let window, !window.ignoresMouseEvents else { return }
            if mode == .move {
                window.performDrag(with: event)
            } else {
                start = (NSEvent.mouseLocation, window.frame)
            }
        }

        override func mouseDragged(with event: NSEvent) {
            guard mode == .resize, let start, let window, !window.ignoresMouseEvents else { return }
            let pointer = NSEvent.mouseLocation
            let width = min(window.maxSize.width, max(window.minSize.width, start.frame.width + pointer.x - start.pointer.x))
            let height = min(window.maxSize.height, max(window.minSize.height, start.frame.height + start.pointer.y - pointer.y))
            let frame = NSRect(x: start.frame.minX, y: start.frame.maxY - height, width: width, height: height)
            window.setFrame(frame, display: true)
        }

        override func mouseUp(with event: NSEvent) { start = nil }
    }
}
