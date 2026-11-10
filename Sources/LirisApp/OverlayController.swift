import AppKit
import SwiftUI

@MainActor
final class OverlayController: NSObject, NSWindowDelegate {
    private weak var model: AppModel?
    private var panel: NSPanel?
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
            panel.hasShadow = false; panel.isMovableByWindowBackground = true
            panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.minSize = NSSize(width: 480, height: 150); panel.maxSize = NSSize(width: 1200, height: 400)
            panel.contentView = NSHostingView(rootView: OverlayView().environmentObject(model))
            panel.delegate = self
            self.panel = panel
        }
        updateLock(); panel?.orderFrontRegardless(); model.overlayVisible = true
    }

    func hide() { panel?.orderOut(nil); model?.overlayVisible = false }
    func updateLock() { panel?.ignoresMouseEvents = model?.overlayLocked == true }
    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }
    private func saveFrame() {
        if let panel { UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "overlayFrame") }
    }
}

struct OverlayView: View {
    @EnvironmentObject private var model: AppModel
    @ViewState private var hovered = false
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "waveform").foregroundStyle(model.accent)
                Text("LIRIS").tracking(2)
                Text("/").foregroundStyle(.white.opacity(0.2))
                Text(model.hasTrack ? model.title : "Menunggu musikmu").lineLimit(1)
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
                if hovered && !model.overlayLocked {
                    Button { model.overlayLocked = true; model.overlayController.updateLock() } label: { Image(systemName: "lock.open") }
                        .buttonStyle(.plain).help("Kunci overlay; buka kunci dari menu bar Liris")
                    Button { model.toggleOverlay() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).padding(.leading, 9).help("Tutup overlay")
                } else { Image(systemName: model.overlayLocked ? "lock.fill" : "hand.draw").opacity(0.5) }
            }.font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.4))
            Spacer(minLength: 0)
            Text(model.record?.hasSync == false ? (model.record?.instrumental == true ? "♪ Instrumental" : "Lirik ini belum memiliki timestamp") : model.currentText)
                .font(.system(size: model.fontSize, weight: .semibold)).tracking(-0.5)
                .foregroundStyle(model.accent).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
            if !model.nextText.isEmpty {
                Text(model.nextText).font(.system(size: max(13, model.fontSize * 0.55), weight: .medium))
                    .foregroundStyle(.white.opacity(0.43)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 25).padding(.vertical, 17)
            .background(Palette.background.opacity(model.opacity), in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(.white.opacity(0.1)))
            .padding(4).onHover { hovered = $0 }
    }
}
