import CoreImage
import CoreImage.CIFilterBuiltins

/// Deskews a detected card region into a flat, upright rectangular image — see
/// docs/plan.md: "CIPerspectiveCorrection deskews using the detected corners." Vision's
/// normalized corner coordinates and CIImage's own coordinate space both put the origin at
/// bottom-left, so converting a region's corners to pixel space is a plain scale, no
/// vertical flip needed.
public enum PerspectiveCorrector {
    public static func correct(_ image: CIImage, region: DetectedCardRegion, imageSize: CGSize) -> CIImage? {
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = image
        filter.topLeft = scaled(region.topLeft, by: imageSize)
        filter.topRight = scaled(region.topRight, by: imageSize)
        filter.bottomLeft = scaled(region.bottomLeft, by: imageSize)
        filter.bottomRight = scaled(region.bottomRight, by: imageSize)
        filter.crop = true
        return filter.outputImage
    }

    private static func scaled(_ point: CGPoint, by size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}
