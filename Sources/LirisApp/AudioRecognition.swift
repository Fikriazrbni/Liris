import AppKit
import Darwin
import AVFoundation
import ScreenCaptureKit


/// Explicitly enabled system-output capture. Never opens a microphone or saves audio.
final class AudioRecognition: NSObject, SCStreamOutput, SCStreamDelegate, AudioCaptureControlling {
    private var stream: SCStream?
    private var pcm = Data()
    private var chunkStart: Double = 0
    private var pending = false
    private var suppressed = false
    private var epoch = UUID()
    private var worker: Process?
    private var nextAttempt: Double = 0
    private var converter: AVAudioConverter?
    private var starting = false
    private var stopping = false
    var activity: AudioCaptureActivity {
        lock.withLock { AudioCaptureActivity(phase: stopping ? .stopping : running ? .active : starting ? .starting : .off, suppressed: suppressed) }
    }
    private var callbacks = 0
    private var convertedFrames = 0
    private var attempts = 0
    private var level: Float = 0
    private var lastCallback = Date.distantPast
    private var lastOutcome = "idle"
    var diagnosticOnly = false
    func reportStartFailure(_ error: Error) {
        let details = error.localizedDescription
        if details.localizedCaseInsensitiveContains("TCC") || details.localizedCaseInsensitiveContains("declined") || details.localizedCaseInsensitiveContains("permission") {
            setStatus("macOS menolak izin capture Liris. Buka Privacy & Security → Screen & System Audio Recording, izinkan Liris, lalu aktifkan audio lagi.")
        } else { setStatus("Audio belum aktif: " + details) }
    }
    var diagnostics: [String: Any] {
        lock.withLock { ["running": running, "starting": starting, "stopping": stopping, "suppressed": suppressed,
            "callbacks": callbacks, "convertedFrames": convertedFrames, "bufferSeconds": Double(pcm.count) / 88200,
            "level": level, "pending": pending, "workerRunning": worker?.isRunning == true,
            "attempts": attempts, "outcome": lastOutcome, "status": message,
            "callbackAge": callbacks == 0 ? -1 : Date().timeIntervalSince(lastCallback), "updatedAt": Date().timeIntervalSince1970] }
    }
    var progressStatus: String {
        lock.withLock {
            guard running else { return message.isEmpty ? "Audio belum diaktifkan. Tekan Aktifkan pengenalan audio sistem." : message }
            if suppressed { return "Audio ditahan karena tab YouTube / YouTube Music sedang bermain." }
            if callbacks == 0 || Date().timeIntervalSince(lastCallback) > 3 { return "Capture aktif tetapi belum menerima audio. Periksa izin dan output audio macOS." }
            if pending { return "ShazamIO sedang mengenali cuplikan…" }
            if lastOutcome == "error" || lastOutcome == "no-match" { return message }
            if Date().timeIntervalSince(lastAudible) > 1.5 { return "Audio masuk tetapi hening/terlalu pelan; menunggu musik." }
            return String(format: "Mengumpulkan cuplikan audio: %.1f / 12 detik", Double(pcm.count) / 88200)
        }
    }
    private let queue = DispatchQueue(label: "id.local.liris.audio")
    private let lock = NSLock()
    private var match: (String, String, Double, Double, Double)?
    private var lastAudible = Date.distantPast
    private var lastAudibleUptime: Double = 0
    private var message = ""
    private var running = false
    var status: String { lock.lock(); defer { lock.unlock() }; return message }
    private var runtime: URL? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Python/bin/python3.12"),
              FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        return url
    }
    private var script: URL? { Bundle.main.resourceURL?.appendingPathComponent("backend/shazamio_worker.py") }
    var configured: Bool { runtime != nil && script.map { FileManager.default.fileExists(atPath: $0.path) } == true }
    var isRunning: Bool { lock.withLock { running } }
    func setSuppressed(_ value: Bool) {
        let old: Process? = lock.withLock {
            guard suppressed != value else { return nil }
            suppressed = value; epoch = UUID(); pcm.removeAll(keepingCapacity: true); match = nil
            return value ? worker : nil
        }
        if old?.isRunning == true { old?.terminate() }
    }
    private func setStatus(_ value: String) { lock.lock(); message = value; lock.unlock() }
    @MainActor func start() async throws {
        guard configured || diagnosticOnly else { throw BridgeError(message: "Runtime ShazamIO belum tersedia. Jalankan scripts/setup-shazamio.sh lalu build ulang aplikasi.") }
        let token = lock.withLock { () -> UUID? in
            guard !starting && !running && !stopping else { return nil }; starting = true; epoch = UUID(); callbacks = 0; convertedFrames = 0; attempts = 0; lastOutcome = "collecting"; pcm.removeAll(); match = nil; return epoch
        }
        guard let token else { return }
        defer { lock.withLock { starting = false; if stream == nil { stopping = false } } }
        guard stream == nil else { return }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard lock.withLock({ epoch == token }), !Task.isCancelled else { return }
        guard let display = content.displays.first else { throw BridgeError(message: "Output audio sistem tidak tersedia.") }
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true; configuration.excludesCurrentProcessAudio = true
        if #available(macOS 15.0, *) { configuration.captureMicrophone = false }
        configuration.sampleRate = 48000; configuration.channelCount = 2
        configuration.width = 2; configuration.height = 2; configuration.minimumFrameInterval = CMTime(seconds: 1, preferredTimescale: 1)
        let capture = SCStream(filter: filter, configuration: configuration, delegate: self)
        try capture.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        guard lock.withLock({ epoch == token }), !Task.isCancelled else { return }
        try await capture.startCapture()
        guard lock.withLock({ epoch == token }) else { try? await capture.stopCapture(); return }
        lock.withLock { stream = capture; running = true }
        setStatus("Mendengarkan audio sistem untuk mengenali lagu…")
    }
    func stop() {
        let values = lock.withLock { () -> (SCStream?, Process?) in
            let values = (stream, worker); stopping = stopping || starting || stream != nil
            stream = nil; running = false; match = nil
            epoch = UUID(); pcm.removeAll(keepingCapacity: false); return values
        }
        if values.1?.isRunning == true { values.1?.terminate() }
        if let old = values.0 { Task { try? await old.stopCapture(); lock.withLock { stopping = false } } }
        setStatus("")
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        guard lock.withLock({ self.stream === stream }) else { return }
        stop(); setStatus("Audio sistem berhenti: " + error.localizedDescription)
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let token = lock.withLock({ running && self.stream === stream ? epoch : nil }) else { return }
        lock.withLock { callbacks += 1; lastCallback = Date() }
        guard sampleBuffer.isValid, let description = sampleBuffer.formatDescription,
              let format = AVAudioFormat(cmAudioFormatDescription: description) as AVAudioFormat?,
              let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        defer { free(list.unsafeMutablePointer) }
        var block: CMBlockBuffer?
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, bufferListSizeNeededOut: nil,
            bufferListOut: list.unsafeMutablePointer, bufferListSize: AudioBufferList.sizeInBytes(maximumBuffers: 2),
            blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: &block) == noErr,
            let source = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: list.unsafePointer, deallocator: nil) else { return }
        source.frameLength = min(source.frameCapacity, AVAudioFrameCount(max(0, CMSampleBufferGetNumSamples(sampleBuffer))))
        guard source.frameLength > 0,
            let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(Double(source.frameLength) * 44100 / format.sampleRate) + 64) else { return }
        if converter?.inputFormat != format { converter = AVAudioConverter(from: format, to: outputFormat) }
        guard let converter else { return }
        var consumed = false
        let result = converter.convert(to: output, error: nil) { _, state in
            if consumed { state.pointee = .noDataNow; return nil }
            consumed = true; state.pointee = .haveData; return source
        }
        guard result != .error, output.frameLength > 0 else { return }
        if let samples = output.floatChannelData?[0] {
            var energy: Float = 0
            for index in stride(from: 0, to: Int(output.frameLength), by: 16) { energy += abs(samples[index]) }
            let amplitude = energy / Float(max(1, Int(output.frameLength) / 16))
            lock.withLock { level = amplitude; convertedFrames += Int(output.frameLength) }
            if amplitude > 0.001 {
                lock.lock(); lastAudible = Date(); lastAudibleUptime = ProcessInfo.processInfo.systemUptime; lock.unlock()
            }
        }
        guard let samples = output.floatChannelData?[0] else { return }
        var bytes = Data(count: Int(output.frameLength) * 2)
        bytes.withUnsafeMutableBytes { raw in
            for index in 0..<Int(output.frameLength) {
                let value = samples[index].isFinite ? max(-1, min(1, samples[index])) : 0
                raw.storeBytes(of: Int16(value * 32767).littleEndian, toByteOffset: index * 2, as: Int16.self)
            }
        }
        var clip: (Data, Double, UUID)?
        lock.lock()
        let now = ProcessInfo.processInfo.systemUptime
        if running && epoch == token && !suppressed && !pending && now >= nextAttempt {
            if pcm.isEmpty { chunkStart = now - Double(output.frameLength) / 44100 }
            pcm.append(bytes)
            let count = 12 * 44100 * 2
            if pcm.count >= count {
                if Date().timeIntervalSince(lastAudible) < 1.5 {
                    if diagnosticOnly { lastOutcome = "capture-test-ok" }
                    else { pending = true; attempts += 1; clip = (Data(pcm.prefix(count)), chunkStart, epoch) }
                }
                pcm.removeAll(keepingCapacity: true)
            }
        }
        lock.unlock()
        if let clip { recognize(clip.0, start: clip.1, token: clip.2) }
    }
    private func recognize(_ audio: Data, start: Double, token: UUID) {
        guard let runtime, let script else { lock.withLock { pending = false }; return }
        Task.detached(priority: .utility) { [self] in
            let process = Process(), input = Pipe(), output = Pipe()
            defer { if process.isRunning { process.terminate() }; lock.withLock { pending = false; worker = nil } }
            do {
                process.executableURL = runtime; process.arguments = ["-I", "-B", script.path]
                var environment = ProcessInfo.processInfo.environment
                environment.removeValue(forKey: "PYTHONPATH"); environment.removeValue(forKey: "PYTHONHOME")
                environment["PYTHONNOUSERSITE"] = "1"
                process.environment = environment
                process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
                _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
                try lock.withLock {
                    guard running && !suppressed && epoch == token else { throw CancellationError() }
                    worker = process
                    try process.run()
                }
                let wav = Self.wave(audio)
                try input.fileHandleForWriting.write(contentsOf: wav)
                try input.fileHandleForWriting.close()
                let deadline = ProcessInfo.processInfo.systemUptime + 23
                while process.isRunning {
                    guard lock.withLock({ running && !suppressed && epoch == token }), ProcessInfo.processInfo.systemUptime < deadline else {
                        process.terminate(); throw BridgeError(message: "Pengenalan audio dibatalkan atau timeout.")
                    }
                    try await Task.sleep(for: .milliseconds(100))
                }
                let data = output.fileHandleForReading.readDataToEndOfFile()
                let response = try JSONDecoder().decode(RecognitionResult.self, from: data)
                lock.withLock {
                    guard running && !suppressed && epoch == token else { return }
                    if process.terminationStatus == 0, response.matched, let title = response.title, let artist = response.artist,
                       let offset = response.offset, offset.isFinite, offset >= 0, offset <= 86400 {
                        match = (title, artist, offset, start, ProcessInfo.processInfo.systemUptime)
                        lastOutcome = "matched"; message = "Lagu dikenali lewat ShazamIO"
                    } else {
                        lastOutcome = response.error == nil ? "no-match" : "error"
                        message = response.error == nil ? "Belum mengenali lagu; mencoba cuplikan berikutnya…" : "ShazamIO gagal (\(response.error ?? "unknown")). Akan mencoba lagi."
                        nextAttempt = ProcessInfo.processInfo.systemUptime + 5
                    }
                }
            } catch {
                lock.withLock {
                    if epoch == token && running { lastOutcome = "error"; message = "Pengenalan audio: " + error.localizedDescription; nextAttempt = ProcessInfo.processInfo.systemUptime + 5 }
                }
            }
        }
    }
    private struct RecognitionResult: Decodable {
        let matched: Bool; let title: String?; let artist: String?; let offset: Double?; let error: String?
    }
    static func wave(_ pcm: Data) -> Data {
        var data = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; data.append(withUnsafeBytes(of: &little) { Data($0) }) }
        append(UInt32(pcm.count + 36)); data.append(Data("WAVEfmt ".utf8))
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1)); append(UInt32(44100))
        append(UInt32(88200)); append(UInt16(2)); append(UInt16(16)); data.append(Data("data".utf8))
        append(UInt32(pcm.count)); data.append(pcm); return data
    }
    func snapshot() -> TrackSnapshot? {
        lock.lock(); defer { lock.unlock() }
        let now = ProcessInfo.processInfo.systemUptime
        guard running, !suppressed, let match, now - match.4 < 25 else { return nil }
        let audible = Date().timeIntervalSince(lastAudible) < 1.5
        let timeline = audible ? now : max(match.3, lastAudibleUptime)
        return TrackSnapshot(available: true, id: "audio|" + match.0 + "|" + match.1, title: match.0, artist: match.1,
            position: match.2 + max(0, timeline - match.3), duration: 0, playing: audible, advertisement: false, positionSource: "recognition")
    }
}
