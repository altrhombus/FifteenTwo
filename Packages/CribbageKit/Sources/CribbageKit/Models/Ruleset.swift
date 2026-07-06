/// House-rule variation lives here and only here — every toggle is explicit and named,
/// never an ad hoc special case inside `Scorer` or `GameEngine`. See docs/plan.md
/// ("House Rules: Correct Base, Configurable Variants").
public struct Ruleset: Codable, Equatable, Sendable {
    public var gameTarget: Int
    public var skunkThreshold: Int
    public var doubleSkunkThreshold: Int
    public var mugginsEnabled: Bool
    /// Whether reaching exactly 31 during pegging scores 2 points instead of the usual 1
    /// for "the go" — a common point of house variation.
    public var exactThirtyOneScoresTwo: Bool

    public init(
        gameTarget: Int = 121,
        skunkThreshold: Int = 91,
        doubleSkunkThreshold: Int = 61,
        mugginsEnabled: Bool = false,
        exactThirtyOneScoresTwo: Bool = true
    ) {
        self.gameTarget = gameTarget
        self.skunkThreshold = skunkThreshold
        self.doubleSkunkThreshold = doubleSkunkThreshold
        self.mugginsEnabled = mugginsEnabled
        self.exactThirtyOneScoresTwo = exactThirtyOneScoresTwo
    }

    public static let standard = Ruleset()
}
