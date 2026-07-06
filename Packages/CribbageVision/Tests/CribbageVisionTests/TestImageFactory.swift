import CoreGraphics
import CoreImage

/// Synthetic test images — this package's Vision/CoreImage pieces are tested against
/// programmatically drawn shapes and colors rather than real photographs (which this
/// project has no way to capture in this environment; see the README's Vision caveat).
/// These verify the pipeline runs correctly and deterministically, not real-world accuracy.
enum TestImageFactory {
    static func solidColor(red: CGFloat, green: CGFloat, blue: CGFloat, size: Int = 40) -> CIImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return CIImage(cgImage: context.makeImage()!)
    }

    /// A white canvas with a black-bordered, poker-card-aspect-ratio rectangle centered
    /// in it — high-contrast and clean, the easiest realistic case for
    /// `VNDetectRectanglesRequest`.
    static func cardOnTable(canvasSize: Int = 400, cardWidth: Int = 200, cardHeight: Int = 280) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: canvasSize, height: canvasSize, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

        let originX = (canvasSize - cardWidth) / 2
        let originY = (canvasSize - cardHeight) / 2
        let cardRect = CGRect(x: originX, y: originY, width: cardWidth, height: cardHeight)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(cardRect)
        context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(4)
        context.stroke(cardRect)

        return context.makeImage()!
    }
}
