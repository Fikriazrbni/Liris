import Foundation
import Testing
@testable import LirisCore

@Suite struct PlaybackClockTests {
    @Test func repeatedIntegerSnapshotsDoNotResetInterpolation() {
        var clock = PlaybackClock()
        clock.update(position: 29, playing: true, uptime: 100, wholeSeconds: true)
        clock.update(position: 29, playing: true, uptime: 100.25, wholeSeconds: true)
        clock.update(position: 29, playing: true, uptime: 100.5, wholeSeconds: true)
        #expect(abs(clock.position(at: 100.75) - 29.75) < 0.001)
        clock.update(position: 30, playing: true, uptime: 101, wholeSeconds: true)
        #expect(abs(clock.position(at: 101.25) - 30.25) < 0.001)
    }

    @Test func stalledProgressCannotAdvanceIntoFutureLyrics() {
        var clock = PlaybackClock()
        clock.update(position: 29, playing: true, uptime: 100, wholeSeconds: true)
        clock.update(position: 29, playing: true, uptime: 105, wholeSeconds: true)
        #expect(clock.position(at: 120) == 30)
    }

    @Test func backwardSeekAndPauseReplaceTheOldClock() {
        var clock = PlaybackClock()
        clock.update(position: 172.187, playing: false, uptime: 100)
        clock.update(position: 29, playing: false, uptime: 101, wholeSeconds: true)
        #expect(clock.position(at: 120) == 29)
        clock.update(position: 29, playing: true, uptime: 121, wholeSeconds: true)
        #expect(abs(clock.position(at: 121.5) - 29.5) < 0.001)
        clock.update(position: 10, playing: true, uptime: 122, wholeSeconds: true)
        #expect(abs(clock.position(at: 122.1) - 10.1) < 0.001)
    }

    @Test func continuousPrecisionAndPlaybackRateArePreserved() {
        var clock = PlaybackClock()
        clock.update(position: 29.725, playing: true, uptime: 100, playbackRate: 1.5)
        #expect(abs(clock.position(at: 102) - 32.725) < 0.001)
        clock.update(position: 32.725, playing: false, uptime: 102)
        #expect(clock.position(at: 200) == 32.725)
    }

    @Test func switchingSourcesResetsTheInterpolationAnchor() {
        var clock = PlaybackClock()
        clock.update(position: 29, playing: true, uptime: 100, wholeSeconds: true)
        clock.update(position: 29.7, playing: true, uptime: 100.7)
        #expect(abs(clock.position(at: 101) - 30) < 0.001)
        clock.update(position: 31, playing: true, uptime: 102, wholeSeconds: true)
        #expect(abs(clock.position(at: 102.5) - 31.5) < 0.001)
    }
}
