// Keep the supplied artwork unchanged; trim only its external canvas padding.
import Cocoa
import ImageIO
import UniformTypeIdentifiers

guard (3...4).contains(CommandLine.arguments.count) else {
    fatalError("Usage: prepare-app-icon.swift input.png cropped-master.png [opaque-package-master.png]")
}
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Cannot decode supplied icon")
}
let bitmap = NSBitmapImageRep(cgImage: image)
let centerX = image.width / 2
let centerY = image.height / 2
func opaque(_ x: Int, _ y: Int) -> Bool {
    (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) >= 0.5
}
precondition(opaque(centerX, centerY), "The icon tile must cover the canvas center")
// Follow the continuous tile through the center, ignoring isolated pixels in
// the transparent margin. Rounded corners do not affect these center runs.
var left = centerX, right = centerX, top = centerY, bottom = centerY
while left > 0 && opaque(left - 1, centerY) { left -= 1 }
while right + 1 < image.width && opaque(right + 1, centerY) { right += 1 }
while top > 0 && opaque(centerX, top - 1) { top -= 1 }
while bottom + 1 < image.height && opaque(centerX, bottom + 1) { bottom += 1 }
let side = max(right - left + 1, bottom - top + 1)
precondition(side > min(image.width, image.height) / 2 && side <= min(image.width, image.height))
let x = min(image.width - side, max(0, (left + right + 1 - side) / 2))
let y = min(image.height - side, max(0, (top + bottom + 1 - side) / 2))
let rect = CGRect(x: x, y: y, width: side, height: side)
guard let cropped = image.cropping(to: rect),
      let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Cannot write cropped master")
}
CGImageDestinationAddImage(destination, cropped, nil)
precondition(CGImageDestinationFinalize(destination))
print("Supplied artwork: \(image.width)×\(image.height); tile center runs: \(right - left + 1)×\(bottom - top + 1)")
print("External canvas crop: \(rect); no redraw, recoloring or geometric distortion")

if CommandLine.arguments.count == 4 {
    // The PNG preview retains its rounded transparent corners. For the app
    // icon, an opaque backing avoids macOS treating the anchor as a separate
    // glass foreground. The system supplies its own outer rounded mask.
    guard let context = CGContext(data: nil, width: cropped.width, height: cropped.height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cropped.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fatalError("Cannot prepare opaque icon backing")
    }
    context.setFillColor(CGColor(red: 0.88, green: 0.90, blue: 0.91, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
    context.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
    let opaqueURL = URL(fileURLWithPath: CommandLine.arguments[3])
    guard let opaque = context.makeImage(),
          let writer = CGImageDestinationCreateWithURL(opaqueURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Cannot write opaque packaging master")
    }
    CGImageDestinationAddImage(writer, opaque, nil)
    precondition(CGImageDestinationFinalize(writer))
    print("Opaque packaging backing added; anchor artwork preserved")
}
