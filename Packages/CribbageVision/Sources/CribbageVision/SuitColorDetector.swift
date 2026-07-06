import CoreImage

/// Classifies red vs. black from the corner crop by averaging its pixel color — see the
/// project's suit-detection scoping decision: full 4-suit classification needs a trained
/// model this project has no photographed training cards to build yet, so only the color
/// split (robust, and needs no training data at all) is automated. The confirmation UI
/// has the person pick the exact suit.
public enum SuitColorDetector {
    /// `nil` if the average color is too close to neutral gray to call confidently (e.g.
    /// a washed-out photo) — the confirmation UI should treat that the same as no guess.
    public static func detectColor(in image: CIImage) -> CardColor? {
        guard let averageFilter = CIFilter(name: "CIAreaAverage") else { return nil }
        averageFilter.setValue(image, forKey: kCIInputImageKey)
        averageFilter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)
        guard let outputImage = averageFilter.outputImage else { return nil }

        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage, toBitmap: &bitmap, rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let red = Double(bitmap[0])
        let green = Double(bitmap[1])
        let blue = Double(bitmap[2])
        // Red ink pulls the red channel well above green; black ink (and its
        // anti-aliased blend with white paper) stays roughly gray *and* noticeably
        // darker than blank card stock. Checking brightness too, not just the
        // red/green gap, is what distinguishes "confidently black" from "no ink here at
        // all" — both are gray, but only one is dark. Thresholds are coarse and
        // untuned (see the type doc comment).
        let redGreenGap = red - green
        if redGreenGap > 8 { return .red }
        let brightness = (red + green + blue) / 3
        if brightness < 120 { return .black }
        return nil
    }
}
