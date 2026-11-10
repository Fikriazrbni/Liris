import Foundation
import LirisCore

let directory = ProcessInfo.processInfo.environment["LIRIS_BRIDGE_TEST_DIRECTORY"].map { URL(fileURLWithPath: $0) } ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Liris/Bridge")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
let input = FileHandle.standardInput, output = FileHandle.standardOutput
func readExact(_ count: Int) -> Data? {
    var data = Data()
    while data.count < count {
        guard let part = try? input.read(upToCount: count - data.count), !part.isEmpty else { return nil }
        data.append(part)
    }
    return data
}
while let header = readExact(4) {
    let size = header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
    guard size > 0 && size <= 65536, let body = readExact(Int(size)) else { break }
    var reply: [String: Any] = ["ok": false]
    if var packet = try? JSONDecoder().decode(AutoPacket.self, from: body), packet.valid {
        packet.receivedAt = Date().timeIntervalSince1970
        packet.command = nil; packet.target = nil
        let file = directory.appendingPathComponent(packet.session + ".json")
        if let encoded = try? JSONEncoder().encode(packet) {
            try? encoded.write(to: file, options: .atomic)
            reply = ["ok": true]
            let commandFile = directory.appendingPathComponent(packet.session + ".command")
            if let data = try? Data(contentsOf: commandFile), let command = try? JSONDecoder().decode(AutoPacket.self, from: data) {
                try? FileManager.default.removeItem(at: commandFile)
                if command.trackID == packet.trackID && command.fresh(at: Date().timeIntervalSince1970) {
                    reply["command"] = command.command; reply["target"] = command.target; reply["trackID"] = command.trackID
                }
            }
        }
    }
    let data = try JSONSerialization.data(withJSONObject: reply)
    var length = UInt32(data.count).littleEndian
    output.write(withUnsafeBytes(of: &length) { Data($0) }); output.write(data)
}
