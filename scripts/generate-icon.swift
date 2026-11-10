import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
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
        NSColor(calibratedRed: 0.79, green: 0.94, blue: 0.48, alpha: 1).setFill(); background.fill()
        NSColor(calibratedRed: 0.79, green: 0.94, blue: 0.48, alpha: 0.09).setStroke()
        background.lineWidth = 3; background.stroke()
        let heights: [CGFloat] = [120, 245, 390, 520, 350, 220, 110]
        for (index, height) in heights.enumerated() {
            let rect = NSRect(x: 247 + CGFloat(index) * 78, y: 512 - height / 2, width: 42, height: height)
            NSColor(calibratedRed: 0.055, green: 0.063, blue: 0.067, alpha: 1).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 21, yRadius: 21).fill()
        }
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
