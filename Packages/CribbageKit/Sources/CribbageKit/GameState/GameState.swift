public enum SkunkResult: String, Codable, Sendable {
    case normal, skunk, doubleSkunk
}

public struct GameState: Codable, Equatable, Sendable {
    public var ruleset: Ruleset
    public var seed: UInt64
    public var handNumber: Int
    public var dealer: Seat
    public var phase: GamePhase

    public var deck: [Card]
    /// The kept hand: 6 cards pre-discard, 4 post-discard. Unlike `peggingRemaining`,
    /// this never shrinks during pegging — it's what final counting scores against.
    public var hands: PerSeat<[Card]>
    /// Cards each seat has not yet played this pegging phase. Starts as a copy of
    /// `hands` when pegging begins and shrinks with every `.playCard`.
    public var peggingRemaining: PerSeat<[Card]>
    public var crib: [Card]
    public var starter: Card?

    public var peggingPile: [Card]
    public var peggingCount: Int
    public var turnToAct: Seat
    /// The seat who said "go" first in the current pegging run, if any.
    public var goSeat: Seat?
    /// Who played the most recent card in the current pegging run — needed to award
    /// the "go" point, since it can't be reliably reconstructed after the fact.
    public var lastCardPlayedBy: Seat?

    public var scores: PerSeat<Int>
    public var lastRoundSummary: RoundSummary?
    public var winner: Seat?

    public init(ruleset: Ruleset = .standard, dealer: Seat = .playerOne, seed: UInt64 = .random(in: .min ... .max)) {
        self.ruleset = ruleset
        self.seed = seed
        self.handNumber = 0
        self.dealer = dealer
        self.phase = .dealing
        self.deck = []
        self.hands = PerSeat(playerOne: [], playerTwo: [])
        self.peggingRemaining = PerSeat(playerOne: [], playerTwo: [])
        self.crib = []
        self.starter = nil
        self.peggingPile = []
        self.peggingCount = 0
        self.turnToAct = dealer.opponent
        self.goSeat = nil
        self.lastCardPlayedBy = nil
        self.scores = PerSeat(playerOne: 0, playerTwo: 0)
        self.lastRoundSummary = nil
        self.winner = nil
    }

    public var skunkResult: SkunkResult? {
        guard phase == .gameOver, let winner else { return nil }
        let loserScore = scores[winner.opponent]
        if loserScore < ruleset.doubleSkunkThreshold { return .doubleSkunk }
        if loserScore < ruleset.skunkThreshold { return .skunk }
        return .normal
    }
}
