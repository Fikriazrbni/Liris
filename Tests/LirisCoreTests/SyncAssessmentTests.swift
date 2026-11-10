import Testing
@testable import LirisCore

private let verse = "[00:10]Unique opening verse\n[00:20]Another complete sentence\n[00:30]A different third verse\n[00:40]This is the last sentence"
private let shifted = "[00:16]Unique opening verse\n[00:26]Another complete sentence\n[00:36]A different third verse\n[00:46]This is the last sentence"

@Suite struct SyncAssessmentTests {
    let track = TrackSignature(title: "Song", artist: "Artist", album: "Studio", duration: 100)

    @Test func wrongMetadataAndPerformanceVersionsAreRejected() {
        for record in [
            LyricsRecord(id: 1, trackName: "Other song", artistName: "Artist", duration: 100, syncedLyrics: verse),
            LyricsRecord(id: 2, trackName: "Song", artistName: "Other artist", duration: 100, syncedLyrics: verse),
            LyricsRecord(id: 3, trackName: "Song", artistName: "Artist", duration: 130, syncedLyrics: verse),
            LyricsRecord(id: 4, trackName: "Song", artistName: "Artist", albumName: "Live at the Arena", duration: 100, syncedLyrics: verse),
            LyricsRecord(id: 5, trackName: "Song", artistName: "Artist", duration: 100, syncedLyrics: "[02:10]Too late")
        ] { #expect(SyncAssessment.assess(record, for: track).confidence == .incompatible) }
    }

    @Test func albumMatchWinsButTimingDisagreementIsNeverCalledVerified() {
        let studio = LyricsRecord(id: 20, trackName: "Song", artistName: "Artist", albumName: "Studio", duration: 100, syncedLyrics: verse)
        let compilation = LyricsRecord(id: 1, trackName: "Song", artistName: "Artist", albumName: "Compilation", duration: 100, syncedLyrics: shifted)
        let result = SyncAssessment.resolve([compilation, studio], for: track, comparedVersions: true)
        #expect(result.record?.id == 20)
        #expect(result.confidence == .uncertain)
        #expect(result.reasons.contains { $0.contains("timing berbeda") })
    }

    @Test func copiesDoNotCreateFalseTimingConflicts() {
        let a = LyricsRecord(id: 1, trackName: "Song", artistName: "Artist", duration: 100, syncedLyrics: verse)
        let b = LyricsRecord(id: 2, trackName: "Song", artistName: "Artist", duration: 100, syncedLyrics: verse)
        #expect(!SyncAssessment.timingDisagrees(a, b))
        #expect(SyncAssessment.resolve([a, b, a], for: track, comparedVersions: true).confidence == .compatible)
        #expect(SyncAssessment.resolve([a, b, a], for: track, comparedVersions: true).alternatives.count == 2)
    }

    @Test func aSavedChoiceIsRespectedWithoutInventingAnOffset() {
        let a = LyricsRecord(id: 1, trackName: "Song", artistName: "Artist", duration: 100, syncedLyrics: verse)
        let b = LyricsRecord(id: 2, trackName: "Song", artistName: "Artist", duration: 100, syncedLyrics: shifted)
        let result = SyncAssessment.resolve([a, b], for: track, comparedVersions: true, preferredID: 2)
        #expect(result.record?.id == 2); #expect(result.savedChoice)
        #expect(result.record?.lines.first?.time == 16)
    }

    @Test func unknownDurationAndOfflineComparisonRemainUncertain() {
        let record = LyricsRecord(id: 1, trackName: "Song", artistName: "Artist", duration: 100, syncedLyrics: verse)
        let unknown = TrackSignature(title: "Song", artist: "Artist", duration: 0)
        #expect(SyncAssessment.assess(record, for: unknown).confidence == .uncertain)
        #expect(SyncAssessment.resolve([record], for: track, comparedVersions: false).confidence == .uncertain)
    }

    @Test func emptyAndMalformedLyricsAreRejectedButPlainLyricsStayReadable() {
        let empty = LyricsRecord(id: 1, trackName: "Song", artistName: "Artist", duration: 100)
        let malformed = LyricsRecord(id: 2, trackName: "Song", artistName: "Artist", duration: 100, syncedLyrics: "[bad]Something")
        let plain = LyricsRecord(id: 3, trackName: "Song", artistName: "Artist", duration: 100, plainLyrics: "Untimed verse")
        #expect(SyncAssessment.assess(empty, for: track).confidence == .incompatible)
        #expect(SyncAssessment.assess(malformed, for: track).confidence == .incompatible)
        #expect(SyncAssessment.assess(plain, for: track).confidence == .uncertain)
    }
}

@Suite struct PlayerTimeMonitorTests {
    @Test func detectsAndRecoversFromAStaleMediaClock() {
        var monitor = PlayerTimeMonitor()
        let result = monitor.evaluate(media: 172.187, progress: 29, visibleClock: 29,
            duration: 322, playing: false, mediaPlaying: false, uptime: 100)
        #expect(result.position == 29); #expect(result.source == .progress); #expect(result.health == .recovered)
    }

    @Test func consistentClocksRetainSubsecondPrecision() {
        var monitor = PlayerTimeMonitor()
        let result = monitor.evaluate(media: 29.75, progress: 29, visibleClock: 29,
            duration: 322, playing: true, mediaPlaying: true, uptime: 100)
        #expect(result.position == 29.75); #expect(result.health == .consistent)
    }

    @Test func bothClocksStallingPausesLyricsAndRecoversAutomatically() {
        var monitor = PlayerTimeMonitor()
        _ = monitor.evaluate(media: 29, progress: 29, duration: 322, playing: true, uptime: 100)
        let stopped = monitor.evaluate(media: 29, progress: 29, duration: 322, playing: true, uptime: 104)
        #expect(stopped.position == nil); #expect(stopped.health == .waiting)
        let recovered = monitor.evaluate(media: 29, progress: 30, duration: 322, playing: true, uptime: 104.25)
        #expect(recovered.position == 30); #expect(recovered.source == .progress)
    }

    @Test func aFrozenProgressBarCanFallBackToMovingMedia() {
        var monitor = PlayerTimeMonitor()
        _ = monitor.evaluate(media: 29, progress: 29, duration: 322, playing: true, uptime: 100)
        let result = monitor.evaluate(media: 33, progress: 29, duration: 322, playing: true, uptime: 104)
        #expect(result.position == 33); #expect(result.source == .media); #expect(result.health == .recovered)
    }

    @Test func aDraggedSliderCannotOverruleTwoAgreeingClocks() {
        var monitor = PlayerTimeMonitor()
        let result = monitor.evaluate(media: 29.7, progress: 100, visibleClock: 29,
            duration: 322, playing: true, mediaPlaying: true, uptime: 100)
        #expect(result.position == 29.7); #expect(result.health == .recovered)
    }

    @Test func invalidClocksAreNotSilentlyConvertedToZero() {
        var monitor = PlayerTimeMonitor()
        let result = monitor.evaluate(media: .nan, progress: -1, visibleClock: .infinity,
            duration: 100, playing: true, uptime: 100)
        #expect(result.position == nil); #expect(result.source == .unavailable)
    }

    @Test func aPausedPlayerAndBackwardSeekAreNotMistakenForBuffering() {
        var monitor = PlayerTimeMonitor()
        _ = monitor.evaluate(media: 100, progress: 100, duration: 322, playing: false, uptime: 100)
        let paused = monitor.evaluate(media: 100, progress: 100, duration: 322, playing: false, uptime: 110)
        #expect(paused.health == .consistent)
        let seek = monitor.evaluate(media: 100, progress: 20, duration: 322, playing: false, uptime: 111)
        #expect(seek.position == 20)
    }

    @Test func recoveryDoesNotRapidlySwitchBackToMediaOnASingleCoincidence() {
        var monitor = PlayerTimeMonitor()
        _ = monitor.evaluate(media: 172, progress: 29, duration: 322, playing: true, uptime: 100)
        for (index, time) in [29.2, 29.4].enumerated() {
            let decision = monitor.evaluate(media: time, progress: 29, duration: 322, playing: true, uptime: 101 + Double(index) / 4)
            #expect(decision.source == .progress)
        }
        let stable = monitor.evaluate(media: 29.6, progress: 29, duration: 322, playing: true, uptime: 101.5)
        #expect(stable.source == .media)
    }

    @Test func missingSliderUsesTheVisibleClock() {
        var monitor = PlayerTimeMonitor()
        let result = monitor.evaluate(media: 172, progress: nil, visibleClock: 29,
            duration: 322, playing: false, uptime: 100)
        #expect(result.source == .clock); #expect(result.position == 29)
    }

    @Test func conflictingUIClocksWaitThenFollowTheOneThatRecovers() {
        var monitor = PlayerTimeMonitor()
        let unknown = monitor.evaluate(media: nil, progress: 100, visibleClock: 29,
            duration: 322, playing: true, uptime: 100)
        #expect(unknown.health == .waiting)
        let moving = monitor.evaluate(media: nil, progress: 100, visibleClock: 30,
            duration: 322, playing: true, uptime: 101)
        #expect(moving.source == .clock); #expect(moving.position == 30)
        let repeated = monitor.evaluate(media: nil, progress: 100, visibleClock: 30,
            duration: 322, playing: true, uptime: 101.25)
        #expect(repeated.source == .clock); #expect(repeated.position == 30)
    }
}
