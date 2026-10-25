import AppKit
import Foundation

let out = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let bounds = NSRect(x: 72, y: 72, width: 880, height: 880)
    let base = NSBezierPath(roundedRect: bounds, xRadius: 200, yRadius: 200)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.16); shadow.shadowBlurRadius = 26; shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.set()
    NSColor(calibratedRed: 0.12, green: 0.45, blue: 0.38, alpha: 1).setFill(); base.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [NSColor(calibratedRed: 0.08, green: 0.40, blue: 0.35, alpha: 1), NSColor(calibratedRed: 0.37, green: 0.73, blue: 0.61, alpha: 1)])!.draw(in: base, angle: 65)
    let leaf = NSBezierPath()
    leaf.move(to: NSPoint(x: 330, y: 338))
    leaf.curve(to: NSPoint(x: 733, y: 747), controlPoint1: NSPoint(x: 197, y: 649), controlPoint2: NSPoint(x: 501, y: 766))
    leaf.curve(to: NSPoint(x: 330, y: 338), controlPoint1: NSPoint(x: 782, y: 471), controlPoint2: NSPoint(x: 583, y: 242))
    NSGraphicsContext.saveGraphicsState()
    let ls = NSShadow(); ls.shadowColor = NSColor(calibratedRed: 0.02, green: 0.22, blue: 0.18, alpha: 0.21); ls.shadowBlurRadius = 22; ls.shadowOffset = NSSize(width: 0, height: -12); ls.set()
    NSColor(calibratedRed: 0.95, green: 0.99, blue: 0.94, alpha: 1).setFill(); leaf.fill()
    NSGraphicsContext.restoreGraphicsState()
    let vein = NSBezierPath(); vein.move(to: NSPoint(x: 284, y: 276)); vein.curve(to: NSPoint(x: 633, y: 640), controlPoint1: NSPoint(x: 418, y: 366), controlPoint2: NSPoint(x: 544, y: 498)); vein.lineWidth = 23; vein.lineCapStyle = .round
    NSColor(calibratedRed: 0.20, green: 0.57, blue: 0.46, alpha: 1).setStroke(); vein.stroke()
    NSColor.white.withAlphaComponent(0.27).setStroke(); base.lineWidth = 2; base.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for s in [16, 32, 128, 256, 512] {
    try render(s).write(to: URL(fileURLWithPath: "\(out)/icon_\(s)x\(s).png"))
    try render(s * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(s)x\(s)@2x.png"))
}
