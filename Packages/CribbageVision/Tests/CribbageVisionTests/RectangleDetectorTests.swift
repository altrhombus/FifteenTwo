import Testing
import CoreImage
@testable import CribbageVision

struct RectangleDetectorTests {
    @Test func detectsAClearCardShapedRectangleOnATable() throws {
        let image = TestImageFactory.cardOnTable()
        let regions = try RectangleDetector.detectCards(in: image)

        #expect(!regions.isEmpty)
        // Not asserting an exact corner match: Vision's own detected corners are its
        // internal best-fit for the quad, not guaranteed to land exactly on the drawn
        // pixels. The meaningful property is that it found *a* high-confidence region.
        #expect(regions.first?.confidence ?? 0 > 0.5)
    }

    @Test func findsNothingInABlankImage() throws {
        let blank = TestImageFactory.solidColor(red: 1, green: 1, blue: 1, size: 400)
        let context = CIContext()
        let cgImage = context.createCGImage(blank, from: blank.extent)!
        let regions = try RectangleDetector.detectCards(in: cgImage)
        #expect(regions.isEmpty)
    }
}
