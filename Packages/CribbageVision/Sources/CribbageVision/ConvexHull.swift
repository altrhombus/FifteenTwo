import CoreGraphics

/// A minimal 2D computational-geometry toolkit — pure and framework-free (just CGPoint),
/// so it's fully testable without Vision or a camera, unlike `SuitShapeAnalyzer` which
/// uses it. Comparing a detected shape's actual area against its convex hull's area is
/// how that analyzer tells a fully convex shape (a diamond) from one with concave
/// notches (a heart).
public enum ConvexHull {
    /// Andrew's monotone chain algorithm — O(n log n), returns hull points in
    /// counter-clockwise order. Fewer than 3 input points has no meaningful hull; the
    /// input itself is returned unchanged.
    public static func hull(of points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        guard sorted.count >= 3 else { return sorted }

        func cross(_ origin: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - origin.x) * (b.y - origin.y) - (a.y - origin.y) * (b.x - origin.x)
        }

        var lower: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }

        var upper: [CGPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }

        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    /// The shoelace formula — the unsigned area of a simple polygon given its vertices
    /// in order (winding direction doesn't matter, since this always returns a
    /// non-negative value).
    public static func polygonArea(of points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var sum: CGFloat = 0
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            sum += current.x * next.y - next.x * current.y
        }
        return abs(sum) / 2
    }
}
