import Testing
@testable import CribbageVision

/// These confirm the mechanism — Vision's contour detection plus `ConvexHull`'s area
/// comparison correctly tells a convex shape from a concave one — using synthetically
/// drawn shapes, not real photographed suit symbols (which this project has no way to
/// capture; see the README's Vision caveat). Real-world accuracy on an actual printed
/// heart/diamond still needs verification on real hardware.
struct SuitShapeAnalyzerTests {
    @Test func aFullyConvexDiamondShapeIsIdentifiedAsADiamond() throws {
        let image = TestImageFactory.filledDiamond()
        let suit = try SuitShapeAnalyzer.distinguishHeartFromDiamond(in: image)
        #expect(suit == .diamonds)
    }

    @Test func aDeeplyNotchedConcaveShapeIsIdentifiedAsAHeart() throws {
        let image = TestImageFactory.filledNotchedShape()
        let suit = try SuitShapeAnalyzer.distinguishHeartFromDiamond(in: image)
        #expect(suit == .hearts)
    }
}
