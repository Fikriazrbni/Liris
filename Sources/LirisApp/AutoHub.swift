import AppKit
import LirisCore

@MainActor
final class AutoHub {
    static let shared = AutoHub()
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Liris/Bridge")
    let audio = AudioRecognition()
    private var selected: AutoPacket?
    var diagnosticExtras: [String: Any] = [:]
    private(set) var route = "Menunggu extension YouTube / YouTube Music"
    func poll() -> TrackSnapshot? {
        var diagnostics = audio.diagnostics
        diagnostics.merge(diagnosticExtras) { _, new in new }
        if let data = try? JSONSerialization.data(withJSONObject: diagnostics),
           let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let directory = cache.appendingPathComponent("id.local.liris")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: directory.appendingPathComponent("audio-status.json"), options: .atomic)
        }
        let now = Date().timeIntervalSince1970
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let packets = files.filter { $0.pathExtension == "json" }.compactMap { file -> AutoPacket? in
            guard let data = try? Data(contentsOf: file), let packet = try? JSONDecoder().decode(AutoPacket.self, from: data), packet.fresh(at: now) else { return nil }
            return packet
        }.sorted {
            if $0.playing != $1.playing { return $0.playing }
            if $0.session == selected?.session { return true }
            if $1.session == selected?.session { return false }
            return ($0.receivedAt ?? 0) > ($1.receivedAt ?? 0)
        }
        audio.setSuppressed(packets.contains { $0.playing })
        if let packet = packets.first(where: { $0.playing }) ?? (audio.snapshot() == nil ? packets.first : nil) {
            selected = packet; route = packet.origin == "youtube" ? "Auto · YouTube (extension)" : "Auto · YouTube Music (extension)"
            let age = max(0, now - (packet.receivedAt ?? now))
            let position = min(packet.duration > 0 ? packet.duration : .greatestFiniteMagnitude, packet.position + (packet.playing && packet.quantized != true ? age : 0))
            return TrackSnapshot(available: true, id: packet.trackID, title: packet.title, artist: packet.artist, album: packet.album,
                position: position, duration: packet.duration, playing: packet.playing, advertisement: packet.advertisement,
                positionSource: packet.quantized == true ? "extension-progress" : "extension", mediaPosition: packet.quantized == true ? nil : position, progressPosition: packet.quantized == true ? position : nil, mediaPlaying: packet.playing, playbackRate: 1)
        }
        selected = nil
        if let snapshot = audio.snapshot() { route = "Auto · audio sistem (ShazamIO)"; return snapshot }
        route = audio.progressStatus
        return nil
    }
    func control(track: TrackSnapshot, position: Double?) throws {
        guard var packet = selected, packet.trackID == track.id, packet.fresh(at: Date().timeIntervalSince1970) else {
            throw BridgeError(message: "Pemutar ini memakai pengenalan audio. Gunakan kontrol aplikasi sumber.")
        }
        packet.command = position == nil ? "toggle" : "seek"; packet.target = position
        packet.receivedAt = Date().timeIntervalSince1970
        try JSONEncoder().encode(packet).write(to: directory.appendingPathComponent(packet.session + ".command"), options: .atomic)
    }
    func stop() { audio.stop(); selected = nil }
}
