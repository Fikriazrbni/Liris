import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let markURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("Sources/LirisApp/Resources/lyric-mark.svg")
guard let mark = NSImage(contentsOf: markURL) else { fatalError("Missing lyric mark at \(markURL.path)") }
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = base * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let factor = CGFloat(size) / 1024
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: factor, y: factor)
        let background = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 218, yRadius: 218)
        NSGradient(starting: NSColor(white: 0.16, alpha: 1), ending: NSColor(white: 0.065, alpha: 1))!
            .draw(in: background, angle: -90)
        NSColor(white: 1, alpha: 0.12).setStroke()
        background.lineWidth = 3; background.stroke()
        mark.draw(in: NSRect(x: 152, y: 287, width: 720, height: 450))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
    }
}

// ICNS is a big-endian chunk container. PNG chunks avoid iconutil's iconservices dependency.
func bigEndian(_ value: UInt32) -> Data {
    var value = value.bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var chunks = Data()
for (type, filename) in [("ic07", "icon_128x128.png"), ("ic08", "icon_256x256.png"),
                          ("ic09", "icon_512x512.png"), ("ic10", "icon_512x512@2x.png")] {
    let png = try Data(contentsOf: directory.appendingPathComponent(filename))
    chunks.append(Data(type.utf8)); chunks.append(bigEndian(UInt32(png.count + 8))); chunks.append(png)
}
var icns = Data("icns".utf8)
icns.append(bigEndian(UInt32(chunks.count + 8))); icns.append(chunks)
try icns.write(to: directory.deletingPathExtension().appendingPathExtension("icns"))
