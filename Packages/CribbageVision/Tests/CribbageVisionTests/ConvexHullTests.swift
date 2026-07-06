import Testing
import CoreGraphics
@testable import CribbageVision

struct ConvexHullTests {
    @Test func hullOfASquareIsItsOwnFourCorners() {
        let square = [
            CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0),
            CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10)
        ]
        let hull = ConvexHull.hull(of: square)
        #expect(hull.count == 4)
        #expect(Set(hull.map { "\($0.x),\($0.y)" }) == Set(square.map { "\($0.x),\($0.y)" }))
    }

    @Test func hullExcludesAnInteriorPoint() {
        let squareWithCenter = [
            CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0),
            CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10),
            CGPoint(x: 5, y: 5)
        ]
        let hull = ConvexHull.hull(of: squareWithCenter)
        #expect(hull.count == 4)
        #expect(!hull.contains { $0.x == 5 && $0.y == 5 })
    }

    @Test func polygonAreaOfATenByTenSquareIsOneHundred() {
        let square = [
            CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0),
            CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10)
        ]
        #expect(ConvexHull.polygonArea(of: square) == 100)
    }

    @Test func polygonAreaOfATriangleMatchesTheKnownFormula() {
        // A right triangle with legs 6 and 4 has area 12.
        let triangle = [CGPoint(x: 0, y: 0), CGPoint(x: 6, y: 0), CGPoint(x: 0, y: 4)]
        #expect(ConvexHull.polygonArea(of: triangle) == 12)
    }

    @Test func areaIsIndependentOfWindingDirection() {
        let clockwise = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 10), CGPoint(x: 10, y: 10), CGPoint(x: 10, y: 0)]
        let counterClockwise = Array(clockwise.reversed())
        #expect(ConvexHull.polygonArea(of: clockwise) == ConvexHull.polygonArea(of: counterClockwise))
    }

    @Test func fewerThanThreePointsHasNoArea() {
        #expect(ConvexHull.polygonArea(of: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]) == 0)
    }
}
