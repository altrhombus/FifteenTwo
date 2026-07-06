import CoreGraphics

/// A detected card-shaped quadrilateral, in normalized image coordinates (origin
/// bottom-left, matching both Vision's and CoreImage's conventions — no flipping needed
/// when handing these straight to `CIPerspectiveCorrection`).
///
/// Corner labels reflect the *source photo's* orientation, not the card's printed
/// orientation — if a card is laid on the table rotated or upside-down, this region's
/// "top left" is still the photo's top left, not the card's. This package assumes cards
/// are laid out reasonably upright when photographed (guided by on-screen instructions in
/// the scanning UI), rather than attempting full rotation-invariant detection.
public struct DetectedCardRegion: Equatable, Sendable {
    public let topLeft: CGPoint
    public let topRight: CGPoint
    public let bottomLeft: CGPoint
    public let bottomRight: CGPoint
    public let confidence: Float

    public init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, confidence: Float) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        self.confidence = confidence
    }
}
