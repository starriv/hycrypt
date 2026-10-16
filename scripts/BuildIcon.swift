import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let bounds = NSRect(
            x: Double(pixels) * 0.08, y: Double(pixels) * 0.08,
            width: Double(pixels) * 0.84, height: Double(pixels) * 0.84)
        let path = NSBezierPath(roundedRect: bounds, xRadius: Double(pixels) * 0.19, yRadius: Double(pixels) * 0.19)
        NSGradient(starting: NSColor.systemBlue, ending: NSColor.systemIndigo)!.draw(in: path, angle: -60)
        let configuration = NSImage.SymbolConfiguration(pointSize: Double(pixels) * 0.47, weight: .medium)
            .applying(.init(paletteColors: [.white]))
        if let lock = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        {
            let ratio = min(Double(pixels) * 0.50 / lock.size.width, Double(pixels) * 0.54 / lock.size.height)
            let width = lock.size.width * ratio
            let height = lock.size.height * ratio
            lock.draw(
                in: NSRect(
                    x: (Double(pixels) - width) / 2, y: (Double(pixels) - height) / 2, width: width, height: height))
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let data = bitmap.representation(using: .png, properties: [:])!
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
