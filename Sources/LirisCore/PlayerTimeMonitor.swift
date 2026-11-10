import Foundation

public enum PlayerTimeSource: String, Sendable { case media, progress, clock, unavailable }
public enum PlayerTimeHealth: String, Sendable { case consistent, recovered, limited, waiting }

public struct PlayerTimeDecision: Sendable {
    public let position: Double?
    public let source: PlayerTimeSource
    public let health: PlayerTimeHealth
    public let reason: String
    public init(position: Double?, source: PlayerTimeSource, health: PlayerTimeHealth, reason: String) {
        self.position = position; self.source = source; self.health = health; self.reason = reason
    }
    public var wholeSeconds: Bool { source == .progress || source == .clock }
}

public struct PlayerTimeMonitor: Sendable {
    private var lastMedia: Double?
    private var lastVisible: Double?
    private var mediaChangedAt: Double?
    private var visibleChangedAt: Double?
    private var lastClock: Double?
    private var lastProgress: Double?
    private var clockChangedAt: Double?
    private var previousPlaying = false
    private var source = PlayerTimeSource.unavailable
    private var agreeingSamples = 0

    public init() {}

    public mutating func evaluate(media: Double?, progress: Double?, visibleClock: Double? = nil,
                                  duration: Double, playing: Bool, mediaPlaying: Bool? = nil,
                                  uptime: Double) -> PlayerTimeDecision {
        func valid(_ value: Double?) -> Double? {
            guard let value, value.isFinite, value >= 0, duration <= 0 || value <= duration + 2 else { return nil }
            return value
        }
        let media = valid(media), progress = valid(progress), visibleClock = valid(visibleClock)
        if playing != previousPlaying {
            mediaChangedAt = uptime; visibleChangedAt = uptime; clockChangedAt = uptime
        }
        let changedClock = visibleClock != nil && lastClock != nil && visibleClock != lastClock
        if visibleClock == nil || lastClock == nil || changedClock { clockChangedAt = uptime }
        lastClock = visibleClock
        let unchangedProgress = progress != nil && lastProgress == progress
        lastProgress = progress
        var visible = progress ?? visibleClock
        var visibleSource: PlayerTimeSource = progress != nil ? .progress : .clock
        var conflictingUI = false
        var unresolvedUI = false
        if let progress, let visibleClock, abs(progress - visibleClock) > 1.25 {
            conflictingUI = true
            // A dragged/stale slider must not overrule two agreeing clocks.
            let clockFresh = !playing || uptime - (clockChangedAt ?? uptime) <= 3
            if clockFresh && (media.map { abs($0 - visibleClock) <= 1.25 } == true || (unchangedProgress && (changedClock || source == .clock))) {
                visible = visibleClock; visibleSource = .clock
            } else if media.map({ abs($0 - progress) <= 1.25 }) != true {
                unresolvedUI = true
            }
        }
        if media == nil || lastMedia == nil || abs((media ?? 0) - (lastMedia ?? 0)) > 0.02 { mediaChangedAt = uptime }
        if visible == nil || visible != lastVisible { visibleChangedAt = uptime }
        lastMedia = media; lastVisible = visible; previousPlaying = playing
        let mediaStalled = playing && uptime - (mediaChangedAt ?? uptime) > 2.5
        let visibleStalled = playing && uptime - (visibleChangedAt ?? uptime) > 3
        let mediaStateWrong = playing && mediaPlaying == false
        let mediaUsable = media != nil && !mediaStalled && !mediaStateWrong

        func decision(_ position: Double?, _ selected: PlayerTimeSource, _ health: PlayerTimeHealth, _ reason: String) -> PlayerTimeDecision {
            PlayerTimeDecision(position: position, source: selected, health: health, reason: reason)
        }

        if unresolvedUI {
            source = .unavailable; agreeingSamples = 0
            return decision(nil, source, .waiting, "Dua jam pemutar berbeda. Menunggu sumber waktu yang sejalan.")
        }

        if let visible, let media, mediaUsable, abs(visible - media) <= 1.25 {
            agreeingSamples += 1
            // Avoid rapid switches at a second boundary after recovering a broken clock.
            if source == .progress || source == .clock, agreeingSamples < 3 {
                source = visibleSource
                return decision(visible, source, .recovered, "Menstabilkan kembali waktu pemutar.")
            }
            source = .media
            return decision(media, source, conflictingUI ? .recovered : .consistent,
                conflictingUI ? "Progress berbeda; otomatis mengikuti jam yang sejalan." : "Waktu media dan pemutar cocok.")
        }
        agreeingSamples = 0
        if let visible, !visibleStalled {
            source = visibleSource
            return decision(visible, source, .recovered, "Waktu tidak sejalan; otomatis mengikuti progress pemutar.")
        }
        if let media, mediaUsable {
            source = .media
            return decision(media, source, visible == nil ? .limited : .recovered,
                visible == nil ? "Hanya satu sumber waktu tersedia." : "Progress berhenti; otomatis mengikuti waktu media yang bergerak.")
        }
        source = .unavailable
        return decision(nil, source, .waiting, "Waktu pemutar belum dapat dipercaya. Lirik dijeda sampai waktu pulih.")
    }
}
