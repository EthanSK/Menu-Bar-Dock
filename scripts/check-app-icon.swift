// Check the actual system app icon against the approved artwork, including
// the ring region where automatic glass treatment previously added white dots.
// Usage: xcrun swift check-app-icon.swift approved-preview.png application.app
import Cocoa
import ImageIO

precondition(CommandLine.arguments.count == 3, "Expected approved PNG and app bundle paths")
func render(_ image: NSImage, size: Int, rect: NSRect? = nil) -> NSBitmapImageRep {
    image.size = NSSize(width: size, height: size)
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: rect ?? NSRect(x: 0, y: 0, width: size, height: size), from: .zero,
               operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
func rgb(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int) -> CGFloat {
    let c = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    return (c.redComponent + c.greenComponent + c.blueComponent) / 3
}
let preview = NSImage(contentsOfFile: CommandLine.arguments[1])!
for appPath in CommandLine.arguments.dropFirst(2) {
    let bitmap = render(NSWorkspace.shared.icon(forFile: URL(fileURLWithPath: appPath).path), size: 256)
    let xs = (0..<256).filter { bitmap.colorAt(x: $0, y: 128)!.alphaComponent > 0.5 }
    let ys = (0..<256).filter { bitmap.colorAt(x: 128, y: $0)!.alphaComponent > 0.5 }
    let left = xs.first!, top = ys.first!, width = xs.last! - left + 1, height = ys.last! - top + 1
    let expected = render(preview, size: 256,
        rect: NSRect(x: left, y: 256 - top - height, width: width, height: height))
    var errors: [CGFloat] = [], bright = 0
    for y in (top + Int(CGFloat(height) * 0.10))..<(top + Int(CGFloat(height) * 0.39)) {
        for x in (left + Int(CGFloat(width) * 0.32))..<(left + Int(CGFloat(width) * 0.68)) {
            guard [(0,0),(-2,0),(2,0),(0,-2),(0,2)].allSatisfy({ rgb(expected,x+$0.0,y+$0.1) < 0.40 }) else { continue }
            let actual = rgb(bitmap, x, y)
            errors.append(abs(actual - rgb(expected,x,y)))
            if actual > 0.55 { bright += 1 }
        }
    }
    precondition(errors.count > 100, "Cannot locate the expected anchor ring")
    let mean = errors.reduce(0,+) / CGFloat(errors.count)
    print("\(appPath): ring samples=\(errors.count), bright artifacts=\(bright), mean luminance error=\(mean)")
    precondition(bright == 0 && mean < 0.03, "System icon does not preserve the approved ring artwork")
    let bundle = Bundle(url: URL(fileURLWithPath: appPath))!
    let name = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as! String
    let iconURL = bundle.bundleURL.appendingPathComponent("Contents/Resources/" + name + ".icns")
    let source = CGImageSourceCreateWithURL(iconURL as CFURL, nil)!
    var sizes = Set<Int>()
    for index in 0..<CGImageSourceGetCount(source) {
        let image = CGImageSourceCreateImageAtIndex(source, index, nil)!
        precondition(image.width == image.height)
        sizes.insert(image.width)
        precondition([CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo),
                     "Icon family contains an alpha layer that may be reinterpreted as glass")
    }
    precondition(sizes.isSuperset(of: [16, 32, 64, 128, 256, 512, 1024]))
    print("Native appearance, ring contrast and complete opaque icon family: PASS")
}
