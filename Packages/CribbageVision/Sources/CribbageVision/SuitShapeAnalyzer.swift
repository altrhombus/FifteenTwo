import Vision
import CoreGraphics
import CribbageKit

/// Distinguishes hearts from diamonds via shape convexity — see the project's
/// suit-detection scoping: diamonds are the only fully convex suit symbol (no concave
/// notches), while hearts have a distinct dip between the two top lobes. This is real,
/// deterministic geometry (Vision's contour detection plus `ConvexHull`'s area
/// comparison), not a trained model, but the convexity threshold below is untuned against
/// real photographed cards (see the project's Vision caveat) — treat it as a helpful
/// default, never a guaranteed-correct one; the confirmation screen always has final say.
///
/// Deliberately doesn't attempt clubs vs. spades: both have concave notches and a stem,
/// and reliably telling "three round lobes" from "one pointed lobe" via untuned geometry
/// is much shakier than the diamond/heart convexity split — see the project's own
/// scoping decision on this.
public enum SuitShapeAnalyzer {
    /// `nil` if no confident single shape was found (e.g. a blank or noisy crop).
    public static func distinguishHeartFromDiamond(in cgImage: CGImage) throws -> Suit? {
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 2.0
        request.detectsDarkOnLight = true // ink is darker (lower luminance) than card stock

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else { return nil }
        let candidates = observation.topLevelContours.compactMap { contour -> (points: [CGPoint], area: CGFloat)? in
            let points = points(of: contour)
            guard points.count >= 3 else { return nil }
            return (points, ConvexHull.polygonArea(of: points))
        }
        // The suit symbol is assumed to be the largest shape in the crop — a reasonable
        // assumption once the crop is already isolated to just the suit-symbol region
        // (see `CornerCropper.cropSuitSymbol`), not the full rank+suit index.
        guard let largest = candidates.max(by: { $0.area < $1.area }) else { return nil }

        let hullArea = ConvexHull.polygonArea(of: ConvexHull.hull(of: largest.points))
        guard hullArea > 0 else { return nil }

        let convexity = largest.area / hullArea
        return convexity > 0.92 ? .diamonds : .hearts
    }

    private static func points(of contour: VNContour) -> [CGPoint] {
        // `normalizedPoints` bridges to a native `[simd_float2]` array (Swift copies out
        // of the ObjC-owned buffer at the property boundary) — wrapping it in
        // `UnsafeBufferPointer` ourselves would only produce a dangling pointer once the
        // temporary conversion's lifetime ends.
        contour.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
    }
}
