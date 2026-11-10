import Foundation
import CryptoKit

public enum LyricsClientError: LocalizedError {
    case invalidResponse, http(Int), throttled(TimeInterval)
    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "Respons layanan lirik tidak dikenali. Coba lagi sebentar."
        case .http(let status): "Layanan lirik sedang bermasalah (HTTP \(status)). Coba lagi nanti."
        case .throttled(let seconds): "Batas permintaan LRCLIB tercapai. Coba lagi dalam \(Int(ceil(seconds))) detik."
        }
    }
}

public actor LyricsClient {
    private let session: URLSession
    private let cacheDirectory: URL?
    private var records: [String: LyricsRecord] = [:]
    private var resolutions: [String: LyricsResolution] = [:]
    private var choices: [String: LyricsRecord] = [:]
    private var searchCache: [String: (Date, [LyricsRecord])] = [:]
    private var retryAfter = Date.distantPast

    public init(session: URLSession = .shared, cacheDirectory: URL? = nil) {
        self.session = session; self.cacheDirectory = cacheDirectory
    }

    public func lookup(title: String, artist: String, album: String = "", duration: Double, bypassCache: Bool = false) async throws -> LyricsRecord? {
        let track = TrackSignature(title: title, artist: artist, album: album, duration: duration)
        let key = [title, artist, album, String(Int(track.duration.rounded()))].joined(separator: "\u{1f}")
        if !bypassCache, let cached = records[key], SyncAssessment.assess(cached, for: track).confidence != .incompatible { return cached }
        if !bypassCache, let file = cacheURL(key), let data = try? Data(contentsOf: file),
           let record = try? JSONDecoder().decode(LyricsRecord.self, from: data), SyncAssessment.assess(record, for: track).confidence != .incompatible {
            records[key] = record; return record
        }
        var query = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        if track.duration > 0 { query.append(URLQueryItem(name: "duration", value: String(Int(track.duration.rounded())))) }
        if !album.isEmpty { query.append(URLQueryItem(name: "album_name", value: album)) }
        var record: LyricsRecord?
        if let data = try await request(path: "get", query: query, allowNotFound: true) {
            record = try JSONDecoder().decode(LyricsRecord.self, from: data)
        }
        // Validate exact results too: a record may advertise the right duration
        // while its lyric timestamps belong to a longer version.
        if record == nil || record.map({ SyncAssessment.assess($0, for: track).confidence == .incompatible }) == true {
            let results = try await search(title + " " + artist)
            record = SyncAssessment.resolve(results, for: track, comparedVersions: true).record
        }
        if let record {
            records[key] = record
            if let file = cacheURL(key), let data = try? JSONEncoder().encode(record) {
                try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: file, options: .atomic)
            }
        }
        return record
    }

    public func search(_ query: String) async throws -> [LyricsRecord] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        guard let data = try await request(path: "search", query: [URLQueryItem(name: "q", value: query)]) else { return [] }
        let results = try JSONDecoder().decode([LyricsRecord].self, from: data)
        searchCache[query] = (Date(), results)
        return results
    }

    /// Compare plausible timing versions once per track, then reuse a versioned archive.
    /// Every archive and saved choice is revalidated against current player metadata.
    public func resolve(_ track: TrackSignature, forceRefresh: Bool = false) async throws -> LyricsResolution {
        let choice: LyricsRecord? = choices[track.key] ?? read(LyricsRecord.self, key: track.key, suffix: "choice")
        let archive: LyricsResolution? = resolutions[track.key] ?? read(LyricsResolution.self, key: track.key, suffix: "assessment-v1")
        if !forceRefresh, let archive, archive.comparedVersions, Date().timeIntervalSince(archive.checkedAt) < 7 * 86400 {
            let result = SyncAssessment.resolve(archive.alternatives + [archive.record, choice].compactMap { $0 },
                for: track, comparedVersions: true, preferredID: choice?.id)
            if result.record != nil {
                var cached = result
                cached.checkedAt = archive.checkedAt
                resolutions[track.key] = cached
                return cached
            }
        }
        var candidates: [LyricsRecord] = []
        var networkError: Error?
        do {
            if let primary = try await lookup(title: track.title, artist: track.artist, album: track.album,
                                               duration: track.duration, bypassCache: forceRefresh) { candidates.append(primary) }
        } catch { networkError = error }
        var compared = false
        do {
            let query = track.title + " " + track.artist
            if !forceRefresh, let cached = searchCache[query], Date().timeIntervalSince(cached.0) < 600 {
                candidates = cached.1 + candidates
            } else { candidates = try await search(query) + candidates }
            compared = true
        } catch { networkError = error }
        if let choice { candidates.append(choice) }
        if networkError != nil, let archive { candidates += archive.alternatives + [archive.record].compactMap { $0 } }
        var result = SyncAssessment.resolve(candidates, for: track, comparedVersions: compared, preferredID: choice?.id)
        if result.record == nil, let networkError { throw networkError }
        if !compared, networkError != nil { result.reasons.append("Pemeriksaan online belum tersedia; lirik lokal tetap dapat dipakai.") }
        // Keep a bounded set, always retaining the selected version.
        result.alternatives = Array(result.alternatives.prefix(32))
        if let selected = result.record, !result.alternatives.contains(where: { $0.id == selected.id }) { result.alternatives.append(selected) }
        resolutions[track.key] = result
        write(result, key: track.key, suffix: "assessment-v1")
        return result
    }

    public func rememberChoice(_ record: LyricsRecord, for track: TrackSignature) {
        guard SyncAssessment.assess(record, for: track).confidence != .incompatible else { return }
        choices[track.key] = record
        write(record, key: track.key, suffix: "choice")
    }

    public func clearChoice(for track: TrackSignature) {
        choices.removeValue(forKey: track.key)
        if let file = archiveURL(track.key, suffix: "choice") { try? FileManager.default.removeItem(at: file) }
    }

    private func archiveURL(_ key: String, suffix: String) -> URL? {
        cacheDirectory?.appendingPathComponent(key + "." + suffix + ".json")
    }
    private func read<T: Decodable>(_ type: T.Type, key: String, suffix: String) -> T? {
        guard let file = archiveURL(key, suffix: suffix), let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    private func write<T: Encodable>(_ value: T, key: String, suffix: String) {
        guard let file = archiveURL(key, suffix: suffix), let data = try? JSONEncoder().encode(value) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    private func request(path: String, query: [URLQueryItem], allowNotFound: Bool = false) async throws -> Data? {
        try Task.checkCancellation()
        guard Date() >= retryAfter else { throw LyricsClientError.throttled(retryAfter.timeIntervalSinceNow) }
        var url = URLComponents(string: "https://lrclib.net/api/\(path)")!
        url.queryItems = query
        var request = URLRequest(url: url.url!)
        request.timeoutInterval = 18
        request.setValue("Liris/0.2.0 (local macOS desktop app)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw LyricsClientError.invalidResponse }
        if response.statusCode == 404 && allowNotFound { return nil }
        if [429, 503].contains(response.statusCode) {
            let value = response.value(forHTTPHeaderField: "Retry-After") ?? ""
            let seconds: Double
            if let number = Double(value), number.isFinite { seconds = max(1, number) }
            else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                seconds = max(1, formatter.date(from: value)?.timeIntervalSinceNow ?? 30)
            }
            retryAfter = Date().addingTimeInterval(seconds)
            throw LyricsClientError.throttled(seconds)
        }
        guard (200..<300).contains(response.statusCode) else { throw LyricsClientError.http(response.statusCode) }
        guard response.mimeType == "application/json" else { throw LyricsClientError.invalidResponse }
        return data
    }

    private func cacheURL(_ key: String) -> URL? {
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return cacheDirectory?.appendingPathComponent(hash).appendingPathExtension("json")
    }
}
