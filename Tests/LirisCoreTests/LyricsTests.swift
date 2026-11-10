import Testing
import Foundation
import CryptoKit
@testable import LirisCore

@Suite struct LyricsTests {
    @Test func testTimestampPrecisionAndMetadata() {
        let lines = LRCParser.parse("\u{feff}[ar:Someone]\n[ti:Song]\n[00:01.2] First\r\n[00:02.34]Second\n[01:03.456] Third")
        #expect(lines.map(\.text) == ["First", "Second", "Third"])
        #expect(lines.map(\.time) == [1.2, 2.34, 63.456])
    }

    @Test func testRepeatedTimestampsAndStableSorting() {
        let lines = LRCParser.parse("[00:30.00][00:10.00]Refrain\n[00:10.00]Harmony\n[00:20.00]")
        #expect(lines.map(\.time) == [10, 10, 20, 30])
        #expect(lines.map(\.text) == ["Refrain", "Harmony", "", "Refrain"])
        #expect(Set(lines.map(\.id)).count == 4)
        #expect(LRCParser.activeIndex(in: lines, at: 10) == 1)
    }

    @Test func testFileOffsetAndUserAdjustment() {
        let lines = LRCParser.parse("[offset:-500]\n[00:00.20]Intro\n[00:02.00]Verse")
        #expect(lines.map(\.time) == [0, 1.5])
        #expect(LRCParser.activeIndex(in: lines, at: 1.3, adjustment: 0.2) == 1)
        #expect(LRCParser.activeIndex(in: lines, at: 1.3, adjustment: -0.2) == 0)
    }

    @Test func testSeekBackwardsAndBeforeFirstLine() {
        let lines = LRCParser.parse("[00:10]One\n[00:20]Two\n[00:30]Three")
        expectNil(LRCParser.activeIndex(in: lines, at: 9.999))
        #expect(LRCParser.activeIndex(in: lines, at: 30) == 2)
        #expect(LRCParser.activeIndex(in: lines, at: 10) == 0)
        #expect(LRCParser.activeIndex(in: lines, at: 900) == 2)
        expectNil(LRCParser.activeIndex(in: [], at: 10))
    }

    @Test func testMalformedAndPlainLyricsDoNotInventTiming() {
        #expect(LRCParser.parse("These are plain lyrics\n[artist:Someone]\n[01:90.00]bad\n[time]bad").isEmpty)
        #expect(LRCParser.parse("").isEmpty)
    }

    @Test func testMatchingRejectsDifferentArtistAndLiveVersion() {
        let wrongArtist = LyricsRecord(id: 1, trackName: "Hujan", artistName: "Other", duration: 200, syncedLyrics: "[00:01]Wrong")
        let live = LyricsRecord(id: 2, trackName: "Hujan", artistName: "Banda", duration: 265, syncedLyrics: "[00:01]Live")
        let plain = LyricsRecord(id: 3, trackName: "Hujan", artistName: "Banda", duration: 200, plainLyrics: "Words")
        let synced = LyricsRecord(id: 4, trackName: "HUJAN", artistName: "Bánda", duration: 202, syncedLyrics: "[00:01]Right")
        #expect(LyricsMatcher.best(in: [wrongArtist, live, plain, synced], title: "Hujan", artist: "Banda", duration: 200)?.id == 4)
        expectNil(LyricsMatcher.best(in: [wrongArtist, live], title: "Hujan", artist: "Banda", duration: 200))
    }

    @Test func testTimeFormattingIsSafe() {
        #expect(TimeLabel.format(-20) == "0:00")
        #expect(TimeLabel.format(.infinity) == "0:00")
        #expect(TimeLabel.format(185.9) == "3:05")
    }

    @Test func testMatchingRejectsTimestampsBeyondSongEvenWhenDurationMatches() {
        let invalid = LyricsRecord(id: 1, trackName: "Song", artistName: "Artist", duration: 239,
                                   syncedLyrics: "[00:21.92]Opening\n[04:15.23]Wrong ending")
        let valid = LyricsRecord(id: 2, trackName: "Song", artistName: "Artist", duration: 239,
                                 syncedLyrics: "[00:26.22]Opening\n[03:49.00]Ending\n[04:30.00]")
        #expect(!invalid.timingFits(duration: 239))
        #expect(valid.timingFits(duration: 239)) // Empty end markers do not invalidate lyrics.
        #expect(LyricsMatcher.best(in: [invalid, valid], title: "Song", artist: "Artist", duration: 239)?.id == 2)
    }
}

final class MockLyricsProtocol: URLProtocol {
    static var respond: ((URLRequest) -> (Int, [String: String], Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, headers, data) = Self.respond(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized) struct LyricsClientTests {
    private func client(cache: URL? = nil) -> LyricsClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockLyricsProtocol.self]
        return LyricsClient(session: URLSession(configuration: configuration), cacheDirectory: cache)
    }

    @Test func testEncodedQueryAndMemoryCache() async throws {
        var requests = 0
        MockLyricsProtocol.respond = { request in
            requests += 1
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            #expect(items.first { $0.name == "track_name" }?.value == "A & B / 夜")
            expectNotNil(request.value(forHTTPHeaderField: "User-Agent"))
            let record = LyricsRecord(id: 7, trackName: "A & B / 夜", artistName: "Art", duration: 200, syncedLyrics: "[00:10]Hello")
            return (200, ["Content-Type": "application/json"], try! JSONEncoder().encode(record))
        }
        let service = client()
        let first = try await service.lookup(title: "A & B / 夜", artist: "Art", duration: 200)
        let second = try await service.lookup(title: "A & B / 夜", artist: "Art", duration: 200)
        #expect(first?.id == 7); #expect(first == second); #expect(requests == 1)
    }

    @Test func testNotFoundFallsBackWithoutPickingWrongArtist() async throws {
        MockLyricsProtocol.respond = { request in
            if request.url!.path.hasSuffix("/get") { return (404, ["Content-Type": "application/json"], Data("{}".utf8)) }
            let records = [LyricsRecord(id: 9, trackName: "Song", artistName: "Wrong Artist", duration: 200)]
            return (200, ["Content-Type": "application/json"], try! JSONEncoder().encode(records))
        }
        let result = try await client().lookup(title: "Song", artist: "Right Artist", duration: 200)
        expectNil(result)
    }

    @Test func testRetryAfterStopsFurtherRequests() async throws {
        var requests = 0
        MockLyricsProtocol.respond = { _ in requests += 1; return (429, ["Retry-After": "60"], Data("throttled".utf8)) }
        let service = client()
        for _ in 0..<2 {
            do { _ = try await service.search("Song"); Issue.record("Expected throttling") }
            catch let error as LyricsClientError {
                guard case .throttled(let seconds) = error else { Issue.record("Wrong error"); return }
                #expect(seconds > 55)
            }
        }
        #expect(requests == 1)
    }

    @Test func testOfflineDiskCacheAcrossClientInstances() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        MockLyricsProtocol.respond = { _ in
            let record = LyricsRecord(id: 10, trackName: "Song", artistName: "Artist", duration: 100, syncedLyrics: "[00:01]Cached")
            return (200, ["Content-Type": "application/json"], try! JSONEncoder().encode(record))
        }
        _ = try await client(cache: directory).lookup(title: "Song", artist: "Artist", duration: 100)
        MockLyricsProtocol.respond = { _ in Issue.record("Offline cache should avoid network"); return (500, [:], Data()) }
        let result = try await client(cache: directory).lookup(title: "Song", artist: "Artist", duration: 100)
        #expect(result?.id == 10)
    }

    @Test func testHTMLResponseDoesNotDecodeAsLyrics() async {
        MockLyricsProtocol.respond = { _ in (200, ["Content-Type": "text/html"], Data("<html>Challenge</html>".utf8)) }
        do { _ = try await client().search("Song"); Issue.record("Expected invalid response") }
        catch { #expect(error is LyricsClientError) }
    }

    @Test func testInvalidExactLyricsAndOldDiskCacheFallBackToValidVersion() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let invalid = LyricsRecord(id: 1, trackName: "Song", artistName: "Artist", duration: 239,
                                   syncedLyrics: "[00:21.92]Opening\n[04:15.23]Wrong ending")
        let valid = LyricsRecord(id: 2, trackName: "Song", artistName: "Artist", duration: 239,
                                 syncedLyrics: "[00:26.22]Opening\n[03:49.00]Ending")
        let key = ["Song", "Artist", "", "239"].joined(separator: "\u{1f}")
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        let file = directory.appendingPathComponent(hash).appendingPathExtension("json")
        try JSONEncoder().encode(invalid).write(to: file)
        var requests = 0
        MockLyricsProtocol.respond = { request in
            requests += 1
            let data = request.url!.path.hasSuffix("/get") ? try! JSONEncoder().encode(invalid) : try! JSONEncoder().encode([invalid, valid])
            return (200, ["Content-Type": "application/json"], data)
        }
        let result = try await client(cache: directory).lookup(title: "Song", artist: "Artist", duration: 239)
        #expect(result?.id == 2); #expect(requests == 2)
        let stored = try JSONDecoder().decode(LyricsRecord.self, from: Data(contentsOf: file))
        #expect(stored.id == 2)
    }

    @Test func smartResolutionComparesVersionsAndReusesItsArchiveOffline() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let a = LyricsRecord(id: 10, trackName: "Song", artistName: "Artist", albumName: "Studio", duration: 100,
            syncedLyrics: "[00:10]A unique opening verse\n[00:20]A second unique sentence\n[00:30]A third complete sentence\n[00:40]The final unique sentence")
        let b = LyricsRecord(id: 20, trackName: "Song", artistName: "Artist", albumName: "Compilation", duration: 100,
            syncedLyrics: "[00:16]A unique opening verse\n[00:26]A second unique sentence\n[00:36]A third complete sentence\n[00:46]The final unique sentence")
        let track = TrackSignature(title: "Song", artist: "Artist", album: "Studio", duration: 100)
        var requests = 0
        MockLyricsProtocol.respond = { request in
            requests += 1
            let data = request.url!.path.hasSuffix("/get") ? try! JSONEncoder().encode(a) : try! JSONEncoder().encode([a, b])
            return (200, ["Content-Type": "application/json"], data)
        }
        let service = client(cache: folder)
        let first = try await service.resolve(track)
        #expect(first.record?.id == 10); #expect(first.confidence == .uncertain); #expect(requests == 2)
        MockLyricsProtocol.respond = { _ in Issue.record("A checked archive should avoid network"); return (500, [:], Data()) }
        let offline = try await client(cache: folder).resolve(track)
        #expect(offline.record?.id == 10); #expect(offline.confidence == .uncertain)
        await service.rememberChoice(b, for: track)
        let saved = try await client(cache: folder).resolve(track)
        #expect(saved.record?.id == 20); #expect(saved.savedChoice)
        let resetClient = client(cache: folder)
        await resetClient.clearChoice(for: track)
        let reset = try await resetClient.resolve(track)
        #expect(reset.record?.id == 10); #expect(!reset.savedChoice)
    }

    @Test func wrongArtistInAnExactResultIsRejectedAutomatically() async throws {
        let bad = LyricsRecord(id: 1, trackName: "Song", artistName: "Cover band", duration: 100, syncedLyrics: "[00:10]Wrong artist")
        let good = LyricsRecord(id: 2, trackName: "Song", artistName: "Artist", duration: 100, syncedLyrics: "[00:10]Correct artist")
        MockLyricsProtocol.respond = { request in
            let data = request.url!.path.hasSuffix("/get") ? try! JSONEncoder().encode(bad) : try! JSONEncoder().encode([bad, good])
            return (200, ["Content-Type": "application/json"], data)
        }
        let found = try await client().lookup(title: "Song", artist: "Artist", duration: 100)
        #expect(found?.id == 2)
    }

    @Test func forceRefreshUsesUpdatedTimingForTheSameRecordID() async throws {
        var refreshed = false
        var requests = 0
        MockLyricsProtocol.respond = { request in
            requests += 1
            let record = LyricsRecord(id: 5, trackName: "Song", artistName: "Artist", duration: 100,
                syncedLyrics: refreshed ? "[00:10]Opening\n[00:20]Middle\n[00:30]Ending" : "[00:16]Opening\n[00:26]Middle\n[00:36]Ending")
            let data = request.url!.path.hasSuffix("/get") ? try! JSONEncoder().encode(record) : try! JSONEncoder().encode([record])
            return (200, ["Content-Type": "application/json"], data)
        }
        let service = client()
        let signature = TrackSignature(title: "Song", artist: "Artist", duration: 100)
        let old = try await service.resolve(signature)
        #expect(old.record?.lines.first?.time == 16)
        refreshed = true
        let new = try await service.resolve(signature, forceRefresh: true)
        #expect(new.record?.lines.first?.time == 10); #expect(requests == 4)
    }

    @Test func offlineLegacyCacheRemainsReadableWithAnUncertainStatus() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        MockLyricsProtocol.respond = { _ in
            let record = LyricsRecord(id: 1, trackName: "Song", artistName: "Artist", duration: 100,
                syncedLyrics: "[00:10]Opening\n[00:20]Middle\n[00:30]Ending")
            return (200, ["Content-Type": "application/json"], try! JSONEncoder().encode(record))
        }
        _ = try await client(cache: folder).lookup(title: "Song", artist: "Artist", duration: 100)
        MockLyricsProtocol.respond = { _ in (500, ["Content-Type": "application/json"], Data("{}".utf8)) }
        let result = try await client(cache: folder).resolve(TrackSignature(title: "Song", artist: "Artist", duration: 100))
        #expect(result.record?.id == 1); #expect(result.confidence == .uncertain); #expect(!result.comparedVersions)
    }
}

private func expectNil<T>(_ value: T?) { #expect(value == nil) }
private func expectNotNil<T>(_ value: T?) { #expect(value != nil) }
