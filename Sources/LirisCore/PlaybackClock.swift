import Foundation

/// Interpolates media snapshots with a monotonic clock. Whole-second UI readings
/// must not reset interpolation on every poll or run ahead of a stalled player.
public struct PlaybackClock: Sendable {
    private var anchorPosition: Double = 0
    private var anchorUptime: Double = 0
    private var lastReading: Double?
    private var quantized = false
    private var playing = false
    private var rate: Double = 1

    public init() {}

    public mutating func update(position: Double, playing: Bool, uptime: Double,
                                wholeSeconds: Bool = false, playbackRate: Double = 1) {
        let position = position.isFinite ? max(0, position) : 0
        let safeRate = playbackRate.isFinite && playbackRate > 0 ? min(playbackRate, 16) : 1
        let repeatedWholeSecond = wholeSeconds && quantized && self.playing && playing
            && lastReading == position && self.rate == safeRate
        if !repeatedWholeSecond {
            anchorPosition = position
            anchorUptime = uptime
        }
        lastReading = position
        quantized = wholeSeconds
        self.playing = playing
        rate = safeRate
    }

    public func position(at uptime: Double) -> Double {
        guard playing else { return anchorPosition }
        let elapsed = max(0, uptime - anchorUptime) * rate
        return anchorPosition + (quantized ? min(elapsed, 1) : elapsed)
    }
}
