import Foundation
import Testing
@testable import LirisApp

private final class FakeAudioCapture: AudioCaptureControlling {
    var activity = AudioCaptureActivity()
    var configured = true
    var starts = 0
    var stops = 0
    var errorReports = 0
    var pauseStart = false
    var continuation: CheckedContinuation<Void, Never>?
    private var cancelled = false

    @MainActor func start() async throws {
        starts += 1; cancelled = false; activity.phase = .starting
        if pauseStart { await withCheckedContinuation { continuation = $0 } }
        if !cancelled { activity.phase = .active }
    }
    func stop() {
        stops += 1; cancelled = true
        activity = AudioCaptureActivity()
    }
    func reportStartFailure(_ error: Error) { errorReports += 1 }
}

@Suite(.serialized) @MainActor
struct AudioControlsTests {
    private func makeModel(_ audio: FakeAudioCapture) -> AppModel {
        AppModel(audio: audio, pollPlayer: { _, _ in nil })
    }
    private func settle() async {
        try? await Task.sleep(for: .milliseconds(20))
    }

    @Test func connectNeverRestoresOldAudioPreference() async {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "autoAudioEnabled")
        let previousSource = defaults.object(forKey: "source")
        defer {
            defaults.set(previous, forKey: "autoAudioEnabled")
            defaults.set(previousSource, forKey: "source")
        }
        defaults.set(true, forKey: "autoAudioEnabled")
        let audio = FakeAudioCapture()
        let subject = makeModel(audio)
        #expect(defaults.object(forKey: "autoAudioEnabled") == nil)
        subject.source = .auto
        defaults.set(true, forKey: "autoAudioEnabled") // Even a stale preference reintroduced later must be ignored.
        for _ in 0..<3 {
            subject.connect()
            await settle()
            #expect(audio.starts == 0)
            subject.disconnect()
        }
        #expect(audio.starts == 0)
        #expect(subject.audioActivity.phase == .off)
    }

    @Test func onlyManualStartEnablesCaptureAndStopDoesNotReconnect() async {
        let audio = FakeAudioCapture()
        let subject = makeModel(audio)
        subject.source = .auto
        subject.enableAudioRecognition() // A disconnected app cannot start capture.
        await settle()
        #expect(audio.starts == 0)
        subject.connected = true
        subject.enableAudioRecognition()
        subject.enableAudioRecognition() // Double click must not create another request.
        await settle()
        #expect(audio.starts == 1)
        #expect(subject.audioActivity.phase == .active)
        subject.stopAudioRecognition()
        #expect(subject.connected)
        #expect(subject.audioActivity.phase == .off)
        subject.connect()
        await settle()
        subject.disconnect()
        #expect(audio.starts == 1)
    }

    @Test func stopWhilePermissionIsPendingCannotEnableLater() async {
        let audio = FakeAudioCapture()
        audio.pauseStart = true
        let model = makeModel(audio)
        model.source = .auto; model.connected = true
        model.enableAudioRecognition()
        await settle()
        #expect(model.audioActivity.phase == .starting)
        model.stopAudioRecognition()
        audio.continuation?.resume(); audio.continuation = nil
        await settle()
        #expect(model.audioActivity.phase == .off)
        #expect(audio.starts == 1)
        #expect(audio.errorReports == 0)
    }

    @Test func heldRecognitionStillShowsCaptureAndUnexpectedStopUpdatesIndicator() {
        let audio = FakeAudioCapture()
        let subject = makeModel(audio)
        audio.activity = AudioCaptureActivity(phase: .active, suppressed: true)
        subject.refreshAudioActivity()
        #expect(subject.audioActivity.isEngaged)
        #expect(subject.audioActivity.suppressed)
        audio.activity = AudioCaptureActivity(phase: .stopping)
        subject.refreshAudioActivity()
        #expect(subject.audioActivity.isEngaged)
        audio.activity = AudioCaptureActivity()
        subject.refreshAudioActivity()
        #expect(!subject.audioActivity.isEngaged)
    }
}
