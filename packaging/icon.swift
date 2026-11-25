import AppKit

// Draw at each native icon size so small Finder and Dock icons stay crisp.
let dir = URL(fileURLWithPath: CommandLine.arguments[1])
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 128)
        transform.concat()
        let dark = NSColor(srgbRed: 0.105, green: 0.12, blue: 0.11, alpha: 1)
        let lime = NSColor(srgbRed: 0.80, green: 0.94, blue: 0.56, alpha: 1)
        dark.setFill()
        NSBezierPath(roundedRect: NSRect(x: 7, y: 7, width: 114, height: 114), xRadius: 27, yRadius: 27).fill()
        let tilt = NSAffineTransform()
        tilt.translateX(by: 64, yBy: 64)
        tilt.rotate(byDegrees: 12)
        tilt.concat()
        for i in 0..<3 {
            let path = NSBezierPath(roundedRect: NSRect(x: -33 + i * 10, y: -35 + i * 7, width: 46, height: 55), xRadius: 8, yRadius: 8)
            (i == 2 ? lime : dark).setFill()
            path.fill()
            lime.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 1 ? "" : "@2x"
        try bitmap.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
