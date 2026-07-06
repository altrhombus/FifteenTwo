import Foundation
import CoreGraphics
import CribbageKit

/// One detected card, with the automated guesses plus everything the confirmation UI
/// needs to let a human correct it before anything downstream (the discard solver) sees
/// it — see docs/plan.md: "a misread feeding 'optimal' advice is worse than no advice."
public struct ScannedCardGuess: Identifiable, Sendable {
    public let id: UUID
    public var guessedRank: Rank?
    public var guessedColor: CardColor?
    /// Only ever `.hearts` or `.diamonds` — see `SuitShapeAnalyzer`'s doc comment for why
    /// clubs/spades aren't attempted. `nil` whenever the color is black (or unknown) or
    /// the shape analysis wasn't confident.
    public var guessedSuit: Suit?
    public var rankConfidence: Float
    /// The deskewed, cropped corner image — shown next to the guess so the person has
    /// something to actually check it against, not just a bare text field.
    public var cornerImage: CGImage?

    public init(
        id: UUID = UUID(),
        guessedRank: Rank?,
        guessedColor: CardColor?,
        guessedSuit: Suit? = nil,
        rankConfidence: Float,
        cornerImage: CGImage?
    ) {
        self.id = id
        self.guessedRank = guessedRank
        self.guessedColor = guessedColor
        self.guessedSuit = guessedSuit
        self.rankConfidence = rankConfidence
        self.cornerImage = cornerImage
    }
}
