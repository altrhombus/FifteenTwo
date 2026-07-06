import Vision
import CoreGraphics

/// Locates card-shaped quadrilaterals in a photo — see docs/plan.md ("Vision Hand-
/// Scanning"): no training needed, playing cards have strong rectangular contrast against
/// a table. Tuned for a standard poker-size card's ~0.71 aspect ratio (2.5"/3.5") rather
/// than Vision's generic-rectangle defaults.
public enum RectangleDetector {
    public static func detectCards(in image: CGImage) throws -> [DetectedCardRegion] {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.55
        request.maximumAspectRatio = 0.85
        request.minimumConfidence = 0.7
        request.maximumObservations = 10 // a full 6-card hand, plus slack for a messy table
        request.minimumSize = 0.05

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        return (request.results ?? []).map { observation in
            DetectedCardRegion(
                topLeft: observation.topLeft,
                topRight: observation.topRight,
                bottomLeft: observation.bottomLeft,
                bottomRight: observation.bottomRight,
                confidence: observation.confidence
            )
        }
    }
}
