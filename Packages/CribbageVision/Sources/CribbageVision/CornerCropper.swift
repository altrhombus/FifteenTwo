import CoreImage

/// Crops the top-left corner index (rank glyph above the suit symbol) from a deskewed,
/// upright card image — see docs/plan.md: "Crop to the standard top-left corner pip."
/// Proportions are tuned to a standard poker-size card's index box, not measured against
/// real photographed cards (see the project's caveat on Vision hand-scanning needing
/// real-world tuning).
public enum CornerCropper {
    public static func cropCorner(of image: CIImage) -> CIImage {
        let extent = image.extent
        let cropWidth = extent.width * 0.22
        let cropHeight = extent.height * 0.32
        let cropRect = CGRect(x: extent.minX, y: extent.maxY - cropHeight, width: cropWidth, height: cropHeight)
        return image.cropped(to: cropRect)
    }
}
