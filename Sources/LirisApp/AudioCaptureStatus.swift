import SwiftUI

enum AudioCapturePhase: String {
    case off, starting, active, stopping
}

struct AudioCaptureActivity: Equatable {
    var phase: AudioCapturePhase = .off
    var suppressed = false
    var isEngaged: Bool { phase != .off }
    var headline: String {
        switch phase {
        case .off: "Audio recognition is off"
        case .starting: "Starting system audio capture…"
        case .active: suppressed ? "Audio capture on · recognition paused" : "Audio recognition is on"
        case .stopping: "Stopping system audio capture…"
        }
    }
    var detail: String {
        switch phase {
        case .off: "Enable audio manually for each session. Connecting only links your player."
        case .starting: "Waiting for macOS permission to capture audio. You can cancel this request."
        case .active: suppressed
            ? "Audio capture is still on. Fingerprints are paused while the extension detects music."
            : "Audio fingerprints are sent to Shazam regularly. Conversations in system audio may be included."
        case .stopping: "Discarding the sample and waiting for capture to stop."
        }
    }
}

protocol AudioCaptureControlling: AnyObject {
    var activity: AudioCaptureActivity { get }
    var configured: Bool { get }
    @MainActor func start() async throws
    func stop()
    func reportStartFailure(_ error: Error)
}

struct AudioCaptureStatusView: View {
    @EnvironmentObject private var model: AppModel
    var compact = false
    private var color: Color { model.audioActivity.isEngaged ? .orange : Palette.muted }

    var body: some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) { summary; control }
            } else {
                HStack(spacing: 18) { summary; Spacer(minLength: 8); control }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(model.audioActivity.isEngaged ? 0.1 : 0.035), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(color.opacity(0.25)))
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: model.audioActivity.isEngaged ? "record.circle.fill" : "waveform.slash")
                .foregroundStyle(color).font(.system(size: 16)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.audioActivity.headline).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                Text(model.audioActivity.detail).font(.system(size: 10)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var control: some View {
        if model.audioActivity.isEngaged {
            Button { model.stopAudioRecognition() } label: {
                Label(model.audioActivity.phase == .stopping ? "Stopping…" : "Stop Audio", systemImage: "stop.circle.fill")
            }.buttonStyle(QuietButton()).foregroundStyle(.orange)
                .disabled(model.audioActivity.phase == .stopping)
                .accessibilityLabel("Stop system audio recognition")
        } else {
            Button("Enable Audio") { model.enableAudioRecognition() }
                .buttonStyle(QuietButton()).disabled(!model.canStartAudioRecognition)
                .help("Select Auto and connect, then enable audio manually. Shazam may analyze conversations in system audio.")
        }
    }
}
