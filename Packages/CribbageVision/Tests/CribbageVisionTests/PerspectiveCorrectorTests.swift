import Testing
import CoreImage
@testable import CribbageVision

struct PerspectiveCorrectorTests {
    @Test func axisAlignedRegionProducesACroppedOutputOfTheExpectedSize() {
        let size = CGSize(width: 400, height: 400)
        let image = TestImageFactory.solidColor(red: 1, green: 1, blue: 1, size: 400)

        // A perfectly axis-aligned quad covering the middle half of the image, in
        // normalized (0...1) coordinates.
        let region = DetectedCardRegion(
            topLeft: CGPoint(x: 0.25, y: 0.75),
            topRight: CGPoint(x: 0.75, y: 0.75),
            bottomLeft: CGPoint(x: 0.25, y: 0.25),
            bottomRight: CGPoint(x: 0.75, y: 0.25),
            confidence: 1.0
        )

        let corrected = PerspectiveCorrector.correct(image, region: region, imageSize: size)
        #expect(corrected != nil)
        if let corrected {
            // No actual perspective distortion in this input, so the corrected extent
            // should match the quad's own size (200x200 of the 400x400 canvas).
            #expect(abs(corrected.extent.width - 200) < 1)
            #expect(abs(corrected.extent.height - 200) < 1)
        }
    }
}
