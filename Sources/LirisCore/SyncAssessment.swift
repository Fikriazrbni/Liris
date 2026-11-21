import Foundation
import CryptoKit

public struct TrackSignature: Codable, Sendable, Equatable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: Double
    public init(title: String, artist: String, album: String = "", duration: Double) {
        self.title = title; self.artist = artist; self.album = album
        self.duration = duration.isFinite ? max(0, duration) : 0
    }
    public var key: String {
        let text = [title, artist, album].map(LyricsMatcher.normalized).joined(separator: "\u{1f}") + "\u{1f}\(Int(duration.rounded()))"
        return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public enum SyncConfidence: String, Codable, Sendable {
    case compatible, uncertain, incompatible
}

public struct LyricsAssessment: Sendable {
    public let confidence: SyncConfidence
    public let reasons: [String]
    public let score: Double
}

public struct LyricsResolution: Codable, Sendable {
    public var record: LyricsRecord?
    public var alternatives: [LyricsRecord]
    public var confidence: SyncConfidence
    public var reasons: [String]
    public var comparedVersions: Bool
    public var checkedAt: Date
    public var savedChoice: Bool
    public init(record: LyricsRecord?, alternatives: [LyricsRecord], confidence: SyncConfidence,
                reasons: [String], comparedVersions: Bool, checkedAt: Date = Date(), savedChoice: Bool = false) {
        self.record = record; self.alternatives = alternatives; self.confidence = confidence
        self.reasons = reasons; self.comparedVersions = comparedVersions; self.checkedAt = checkedAt
        self.savedChoice = savedChoice
    }
}

public enum SyncAssessment {
    public static func assess(_ record: LyricsRecord, for track: TrackSignature) -> LyricsAssessment {
        var failures: [String] = [], warnings: [String] = []
        if LyricsMatcher.normalized(record.trackName) != LyricsMatcher.normalized(track.title) { failures.append("The lyrics title differs from the track title.") }
        if LyricsMatcher.normalized(record.artistName) != LyricsMatcher.normalized(track.artist) { failures.append("The lyrics artist differs from the player’s artist.") }
        if !record.duration.isFinite || record.duration < 0 { failures.append("This lyrics version has an invalid duration.") }
        if track.duration > 0 && record.duration > 0 && abs(record.duration - track.duration) > 5 { failures.append("The duration of this lyrics version differs by more than 5 seconds.") }
        if record.duration == 0 { warnings.append("The duration of this lyrics version is unknown.") }
        if !record.timingFits(duration: track.duration) { failures.append("A lyric timestamp falls beyond the end of the song.") }
        let wantedVersion = versionHints(track.title + " " + track.album)
        let foundVersion = versionHints(record.trackName + " " + (record.albumName ?? ""))
        if wantedVersion != foundVersion && (!wantedVersion.isEmpty || !foundVersion.isEmpty) {
            failures.append("The live, remix, or acoustic version label differs.")
        }
        let lines = record.lines.filter { !$0.text.isEmpty }
        if !record.instrumental && lines.isEmpty && (record.plainLyrics ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append("This version contains no lyrics.")
        }
        if let raw = record.syncedLyrics, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, lines.isEmpty {
            failures.append("The timed lyrics could not be read.")
        }
        if record.instrumental && !lines.isEmpty { failures.append("The instrumental tag conflicts with the lyrics.") }
        if !record.instrumental && lines.isEmpty { warnings.append("These lyrics have no timestamps for automatic sync.") }
        if track.duration == 0 { warnings.append("The player has not reported a duration. The lyrics version is uncertain.") }
        if !lines.isEmpty && lines.count < 3 && track.duration > 60 { warnings.append("This version has very few timestamps for the length of the song.") }
        if lines.count >= 8 {
            let unique = Set(lines.map { Int(($0.time * 10).rounded()) }).count
            if Double(unique) / Double(lines.count) < 0.5 { warnings.append("Many lines share the same timestamp.") }
        }
        let albumMatch = !track.album.isEmpty && LyricsMatcher.normalized(record.albumName ?? "") == LyricsMatcher.normalized(track.album)
        let score = (record.hasSync || record.instrumental ? 100.0 : 0) + (albumMatch ? 35 : 0)
            - (track.duration > 0 ? abs(record.duration - track.duration) * 3 : 0) - Double(warnings.count) * 15
        return LyricsAssessment(confidence: failures.isEmpty ? (warnings.isEmpty ? .compatible : .uncertain) : .incompatible,
                                reasons: failures + warnings, score: score)
    }

    public static func resolve(_ records: [LyricsRecord], for track: TrackSignature, comparedVersions: Bool,
                               preferredID: Int? = nil) -> LyricsResolution {
        var seen = Set<Int>()
        let ranked = records.filter { seen.insert($0.id).inserted }
            .map { ($0, assess($0, for: track)) }
            .filter { $0.1.confidence != .incompatible }
            .sorted { lhs, rhs in
                if lhs.1.score != rhs.1.score { return lhs.1.score > rhs.1.score }
                return lhs.0.id < rhs.0.id
            }
        let preferred = preferredID.flatMap { id in ranked.first { $0.0.id == id } }
        guard let chosen = preferred ?? ranked.first else {
            return LyricsResolution(record: nil, alternatives: [], confidence: .incompatible,
                reasons: ["No lyrics version matches the title, artist, and track timing."], comparedVersions: comparedVersions)
        }
        var reasons = chosen.1.reasons
        let hasConflict = preferred == nil && ranked.contains { $0.0.id != chosen.0.id && timingDisagrees(chosen.0, $0.0) }
        if hasConflict { reasons.append("Available versions have different timing. Alignment with the vocals is uncertain.") }
        if !comparedVersions { reasons.append("Couldn’t compare alternate versions. Using the available lyrics.") }
        return LyricsResolution(record: chosen.0, alternatives: ranked.map(\.0),
            confidence: reasons.isEmpty ? .compatible : .uncertain, reasons: reasons,
            comparedVersions: comparedVersions, savedChoice: preferred != nil)
    }

    /// Compare shared unique lines, rather than treating copied records as independent votes.
    /// Disagreement signals uncertainty; it never proves which version matches the vocals.
    public static func timingDisagrees(_ lhs: LyricsRecord, _ rhs: LyricsRecord) -> Bool {
        func anchors(_ record: LyricsRecord) -> [String: Double] {
            let grouped = Dictionary(grouping: record.lines.filter { !$0.text.isEmpty }, by: { LyricsMatcher.normalized($0.text) })
            return grouped.filter { $0.value.count == 1 && $0.key.count >= 8 }.mapValues { $0[0].time }
        }
        let a = anchors(lhs), b = anchors(rhs)
        let differences = a.compactMap { key, time in b[key].map { abs($0 - time) } }.sorted()
        guard differences.count >= 4 else { return false }
        return differences[differences.count / 2] > 2
    }

    private static func versionHints(_ text: String) -> Set<String> {
        let value = " " + LyricsMatcher.normalized(text) + " "
        return Set(["live", "acoustic", "unplugged", "remix", "karaoke", "instrumental", "sped up", "slowed", "radio edit"]
            .filter { value.contains(" " + $0 + " ") })
    }
}
