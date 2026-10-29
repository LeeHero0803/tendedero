// Original Lineboard release icon: a single folded sheet crossed by a diagonal
// teal line. Does not reuse the upstream clothespin/screenshots icon artwork.
import AppKit

let output = CommandLine.arguments[1]
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(srgbRed: 0.10, green: 0.22, blue: 0.25, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 180, yRadius: 180).fill()
let sheet = NSBezierPath()
sheet.move(to: NSPoint(x: 310, y: 250))
sheet.line(to: NSPoint(x: 714, y: 250))
sheet.line(to: NSPoint(x: 714, y: 660))
sheet.line(to: NSPoint(x: 594, y: 780))
sheet.line(to: NSPoint(x: 310, y: 780))
sheet.close()
NSColor(srgbRed: 0.95, green: 0.96, blue: 0.91, alpha: 1).setFill()
sheet.fill()
let fold = NSBezierPath()
fold.move(to: NSPoint(x: 594, y: 780))
fold.line(to: NSPoint(x: 594, y: 660))
fold.line(to: NSPoint(x: 714, y: 660))
fold.close()
NSColor(srgbRed: 0.65, green: 0.76, blue: 0.72, alpha: 1).setFill()
fold.fill()
let line = NSBezierPath()
line.move(to: NSPoint(x: 220, y: 390))
line.line(to: NSPoint(x: 804, y: 600))
line.lineWidth = 38
line.lineCapStyle = .round
NSColor(srgbRed: 0.36, green: 0.72, blue: 0.66, alpha: 1).setStroke()
line.stroke()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
