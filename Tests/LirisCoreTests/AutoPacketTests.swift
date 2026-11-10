import Foundation
import Testing
@testable import LirisCore

@Suite struct AutoPacketTests {
    func packet(_ overrides: [String: Any] = [:]) throws -> AutoPacket {
        var value: [String: Any] = ["session":"tab_1", "origin":"youtube", "trackID":"video", "title":"Song", "artist":"Artist", "album":"", "position":12.5, "duration":100, "playing":true, "advertisement":false, "receivedAt":100]
        value.merge(overrides) { _, new in new }
        return try JSONDecoder().decode(AutoPacket.self, from: JSONSerialization.data(withJSONObject: value))
    }
    @Test func rejectsPathsAndUnapprovedSources() throws {
        #expect(try !packet(["session":"../escape"]).valid)
        #expect(try !packet(["origin":"other-site"]).valid)
        #expect(try !packet(["position":-1]).valid)
    }
    @Test func staleOrFutureHeartbeatsAreRejected() throws {
        #expect(try packet().fresh(at:101))
        #expect(try !packet().fresh(at:104))
        #expect(try !packet().fresh(at:99))
    }
}
