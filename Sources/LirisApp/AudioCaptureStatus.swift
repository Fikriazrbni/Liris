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
        case .off: "Pengenalan audio mati"
        case .starting: "Mengaktifkan audio sistem…"
        case .active: suppressed ? "Audio aktif · pengenalan ditahan" : "Pengenalan audio aktif"
        case .stopping: "Menghentikan audio sistem…"
        }
    }
    var detail: String {
        switch phase {
        case .off: "Selalu aktifkan manual. Hubungkan tidak menyalakan audio."
        case .starting: "Menunggu izin capture macOS. Kamu bisa membatalkannya."
        case .active: suppressed
            ? "Capture masih aktif; signature Shazam ditahan selama extension memutar musik."
            : "Signature cuplikan dikirim berulang ke Shazam. Percakapan bisa ikut teranalisis."
        case .stopping: "Cuplikan dibuang; menunggu capture berhenti."
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
                Label(model.audioActivity.phase == .stopping ? "Menghentikan…" : "Matikan audio", systemImage: "stop.circle.fill")
            }.buttonStyle(QuietButton()).foregroundStyle(.orange)
                .disabled(model.audioActivity.phase == .stopping)
                .accessibilityLabel("Matikan pengenalan audio sistem")
        } else {
            Button("Aktifkan audio") { model.enableAudioRecognition() }
                .buttonStyle(QuietButton()).disabled(!model.canStartAudioRecognition)
                .help("Pilih Auto dan Hubungkan, lalu aktifkan secara manual. Audio output termasuk percakapan dapat dianalisis Shazam.")
        }
    }
}
