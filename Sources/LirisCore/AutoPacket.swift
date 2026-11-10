import Foundation

public struct AutoPacket: Codable, Sendable {
    public var session: String
    public var origin: String
    public var trackID: String
    public var title: String
    public var artist: String
    public var album: String
    public var position: Double
    public var duration: Double
    public var playing: Bool
    public var advertisement: Bool
    public var quantized: Bool?
    public var receivedAt: Double?
    public var command: String?
    public var target: Double?
    public var valid: Bool {
        ["youtube", "youtube-music"].contains(origin) && session.range(of: "^[a-zA-Z0-9_-]{1,100}$", options: .regularExpression) != nil
        && !title.isEmpty && title.count <= 1000 && artist.count <= 1000 && album.count <= 1000 && trackID.count <= 1000
        && position.isFinite && duration.isFinite && position >= 0 && duration >= 0 && position <= 864000 && duration <= 864000
    }
    public func fresh(at now: Double) -> Bool { valid && receivedAt.map { now - $0 >= 0 && now - $0 < 3 } == true }
}
