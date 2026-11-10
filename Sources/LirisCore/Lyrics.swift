import Foundation

public struct LyricLine: Identifiable, Equatable, Sendable {
    public let id: Int
    public let time: TimeInterval
    public let text: String
    public init(id: Int, time: TimeInterval, text: String) {
        self.id = id; self.time = time; self.text = text
    }
}

public enum LRCParser {
    /// Supports repeated timestamps, centiseconds/milliseconds, BOM and file offsets.
    public static func parse(_ input: String) -> [LyricLine] {
        let regex = try! NSRegularExpression(pattern: #"\[(\d{1,3}):([0-5]\d)(?:[.:](\d{1,3}))?\]"#)
        let offsetRegex = try! NSRegularExpression(pattern: #"(?i)\[offset:\s*([+-]?\d+)\s*\]"#)
        let inputRange = NSRange(input.startIndex..., in: input)
        var offset = 0.0
        if let m = offsetRegex.firstMatch(in: input, range: inputRange), let r = Range(m.range(at: 1), in: input) {
            offset = (Double(input[r]) ?? 0) / 1000
        }
        var values: [(Double, String, Int)] = []
        for raw in input.components(separatedBy: .newlines) {
            let line = raw.replacingOccurrences(of: "\u{feff}", with: "")
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            guard let last = matches.last, let end = Range(last.range, in: line)?.upperBound else { continue }
            let text = String(line[end...]).trimmingCharacters(in: .whitespaces)
            for match in matches {
                func group(_ n: Int) -> String { Range(match.range(at: n), in: line).map { String(line[$0]) } ?? "" }
                let fraction = group(3)
                let time = (Double(group(1)) ?? 0) * 60 + (Double(group(2)) ?? 0)
                    + (fraction.isEmpty ? 0 : (Double(fraction) ?? 0) / pow(10, Double(fraction.count)))
                values.append((max(0, time + offset), text, values.count))
            }
        }
        return values.sorted { $0.0 == $1.0 ? $0.2 < $1.2 : $0.0 < $1.0 }
            .enumerated().map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }

    /// Positive adjustment advances the lyrics. Before the first timestamp returns nil.
    public static func activeIndex(in lines: [LyricLine], at position: TimeInterval, adjustment: TimeInterval = 0) -> Int? {
        let target = position + adjustment
        var low = 0, high = lines.count
        while low < high {
            let mid = (low + high) / 2
            if lines[mid].time <= target { low = mid + 1 } else { high = mid }
        }
        return low == 0 ? nil : low - 1
    }
}

public struct LyricsRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let trackName: String
    public let artistName: String
    public let albumName: String?
    public let duration: Double
    public let instrumental: Bool
    public let plainLyrics: String?
    public let syncedLyrics: String?
    public var lines: [LyricLine] { LRCParser.parse(syncedLyrics ?? "") }
    public var hasSync: Bool { !lines.isEmpty }

    /// A different timing version must not silently outlive the actual song.
    /// Ignore empty end markers; imported files remain available for manual use.
    public func timingFits(duration playbackDuration: Double) -> Bool {
        let effectiveDuration = playbackDuration > 0 ? playbackDuration : duration
        guard effectiveDuration > 0 else { return true }
        let meaningfulLines = lines.filter { !$0.text.isEmpty }
        guard let last = meaningfulLines.last else { return true }
        return last.time <= effectiveDuration + 3
    }

    public init(id: Int, trackName: String, artistName: String, albumName: String? = nil,
                duration: Double, instrumental: Bool = false, plainLyrics: String? = nil, syncedLyrics: String? = nil) {
        self.id = id; self.trackName = trackName; self.artistName = artistName
        self.albumName = albumName; self.duration = duration; self.instrumental = instrumental
        self.plainLyrics = plainLyrics; self.syncedLyrics = syncedLyrics
    }
}

public enum LyricsMatcher {
    public static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Never silently attach a similarly named song or a different live/remix version.
    public static func best(in results: [LyricsRecord], title: String, artist: String, duration: Double) -> LyricsRecord? {
        results.filter {
            normalized($0.trackName) == normalized(title)
                && normalized($0.artistName) == normalized(artist)
                && (duration <= 0 || abs($0.duration - duration) <= 5)
                && $0.timingFits(duration: duration)
        }.sorted {
            if $0.hasSync != $1.hasSync { return $0.hasSync }
            return abs($0.duration - duration) < abs($1.duration - duration)
        }.first
    }
}

public enum TimeLabel {
    public static func format(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let whole = Int(max(0, seconds))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}
