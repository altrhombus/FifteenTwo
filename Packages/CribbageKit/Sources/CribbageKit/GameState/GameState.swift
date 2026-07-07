public enum SkunkResult: String, Codable, Sendable {
    case normal, skunk, doubleSkunk
}

public struct GameState: Codable, Equatable, Sendable {
    public var ruleset: Ruleset
    /// The seed behind the current hand's shuffle — `nil` before the first deal. See
    /// `Seed256`'s doc comment for why this lives on the move, not generated in
    /// `GameEngine.reduce`.
    public var currentSeed: Seed256?
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
    /// Every pegging point each seat has scored this hand (15s, 31s, pairs, runs, and the
    /// "go"/last-card point), accumulated so Beginner Mode can itemize pegging the same way
    /// it itemizes the show. Reset each deal.
    public var peggingEvents: PerSeat<[ScoreEvent]>
    /// The dealer's "his heels" cut bonus this hand, if the starter was a jack — kept as a
    /// real `ScoreEvent` (not just a silent +2) so it can be surfaced in the breakdown.
    public var hisHeelsEvent: ScoreEvent?

    public var scores: PerSeat<Int>
    public var lastRoundSummary: RoundSummary?
    public var winner: Seat?
    /// The counting decision currently owed, when `ruleset.mugginsEnabled` makes the show
    /// interactive. `nil` whenever muggins is off, or once a hand has been fully counted.
    public var pendingCount: PendingCount?

    public init(ruleset: Ruleset = .standard, dealer: Seat = .playerOne) {
        self.ruleset = ruleset
        self.currentSeed = nil
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
        self.peggingEvents = PerSeat(playerOne: [], playerTwo: [])
        self.hisHeelsEvent = nil
        self.scores = PerSeat(playerOne: 0, playerTwo: 0)
        self.lastRoundSummary = nil
        self.winner = nil
        self.pendingCount = nil
    }

    public var skunkResult: SkunkResult? {
        guard phase == .gameOver, let winner else { return nil }
        let loserScore = scores[winner.opponent]
        if loserScore < ruleset.doubleSkunkThreshold { return .doubleSkunk }
        if loserScore < ruleset.skunkThreshold { return .skunk }
        return .normal
    }
}
