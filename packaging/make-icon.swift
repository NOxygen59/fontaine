// Draws Fontaine's icon (1024×1024 PNG): an indigo-to-violet gradient, a white "A" drawn as
// strokes and three lines of "text" beside it. Our own drawing: no font used.
// swift packaging/make-icon.swift packaging/icon-1024.png
import AppKit

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                                 hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGradient(colors: [NSColor(calibratedRed: 0.30, green: 0.22, blue: 0.85, alpha: 1),
                    NSColor(calibratedRed: 0.78, green: 0.30, blue: 0.80, alpha: 1)])?.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -55)
NSColor.white.setStroke()
NSColor.white.setFill()
// The "A": two thick strokes and a crossbar, with serif feet.
let a = NSBezierPath()
a.lineWidth = 78
a.lineCapStyle = .butt
a.lineJoinStyle = .round
a.move(to: NSPoint(x: 210, y: 250))
a.line(to: NSPoint(x: 400, y: 780))
a.line(to: NSPoint(x: 590, y: 250))
a.move(to: NSPoint(x: 278, y: 440))
a.line(to: NSPoint(x: 522, y: 440))
a.stroke()
for x in [210.0, 590.0] {
    NSBezierPath(roundedRect: NSRect(x: x - 85, y: 222, width: 170, height: 44), xRadius: 22, yRadius: 22).fill()
}
// Lines of text, getting shorter.
for (i, w) in [190.0, 150.0, 110.0].enumerated() {
    let y = 640.0 - Double(i) * 150
    NSColor.white.withAlphaComponent(0.85 - Double(i) * 0.2).setFill()
    NSBezierPath(roundedRect: NSRect(x: 680, y: y, width: w, height: 52), xRadius: 26, yRadius: 26).fill()
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
