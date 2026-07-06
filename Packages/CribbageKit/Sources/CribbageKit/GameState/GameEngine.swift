/// The pure cribbage game-state reducer. Every rule about *when* things are allowed to
/// happen lives here; `Scorer` only knows how to score a fixed 5-card combination.
public enum GameEngine {
    public static func reduce(_ state: GameState, applying move: Move) -> GameState {
        switch move {
        case .dealHand(let seed):
            return dealHand(state, seed: seed)
        case .discard(let seat, let cards):
            return discard(state, seat: seat, cards: cards)
        case .cutForStarter:
            return cutForStarter(state)
        case .playCard(let seat, let card):
            return playCard(state, seat: seat, card: card)
        case .sayGo(let seat):
            return sayGo(state, seat: seat)
        }
    }

    /// Cards `seat` may legally play right now (empty if it isn't their turn, or the
    /// phase isn't pegging).
    public static func legalPlays(for seat: Seat, in state: GameState) -> [Card] {
        guard state.phase == .pegging, state.turnToAct == seat else { return [] }
        return state.peggingRemaining[seat].filter { state.peggingCount + $0.rank.pipValue <= 31 }
    }

    // MARK: - Dealing

    private static func dealHand(_ state: GameState, seed: Seed256) -> GameState {
        var next = state
        if next.phase == .counting {
            next.dealer = next.dealer.opponent
        }
        next.handNumber += 1
        next.currentSeed = seed

        var rng = Xoshiro256StarStar(seed: seed)
        var shuffled = Deck.standard52
        shuffled.shuffle(using: &rng)

        next.hands = PerSeat(playerOne: Array(shuffled[0..<6]), playerTwo: Array(shuffled[6..<12]))
        next.deck = Array(shuffled[12...])
        next.peggingRemaining = PerSeat(playerOne: [], playerTwo: [])
        next.crib = []
        next.starter = nil
        next.peggingPile = []
        next.peggingCount = 0
        next.goSeat = nil
        next.lastCardPlayedBy = nil
        next.lastRoundSummary = nil
        next.phase = .discarding
        return next
    }

    // MARK: - Discarding

    private static func discard(_ state: GameState, seat: Seat, cards: [Card]) -> GameState {
        precondition(state.phase == .discarding, "Can only discard during the discarding phase")
        precondition(cards.count == 2, "Must discard exactly 2 cards, got \(cards.count)")

        var next = state
        var hand = next.hands[seat]
        for card in cards {
            precondition(hand.contains(card), "Discarded card \(card) is not in \(seat)'s hand")
            hand.removeAll { $0 == card }
        }
        next.hands[seat] = hand
        next.crib.append(contentsOf: cards)

        if next.hands.playerOne.count == 4 && next.hands.playerTwo.count == 4 {
            next.phase = .cutStarter
        }
        return next
    }

    // MARK: - Cutting the starter

    private static func cutForStarter(_ state: GameState) -> GameState {
        precondition(state.phase == .cutStarter, "Can only cut for starter during the cutStarter phase")
        guard let starter = state.deck.first else {
            preconditionFailure("Deck unexpectedly empty when cutting for starter")
        }

        var next = state
        next.starter = starter
        if starter.rank == .jack {
            next.scores[next.dealer] += 2 // "his heels"
        }
        next.peggingRemaining = next.hands
        next.turnToAct = next.dealer.opponent
        next.phase = .pegging

        if let winner = checkWinner(next) {
            next.winner = winner
            next.phase = .gameOver
        }
        return next
    }

    // MARK: - Pegging

    private static func playCard(_ state: GameState, seat: Seat, card: Card) -> GameState {
        precondition(state.phase == .pegging, "Can only play cards during pegging")
        precondition(state.turnToAct == seat, "It is not \(seat)'s turn to act")
        precondition(state.peggingRemaining[seat].contains(card), "\(card) is not in \(seat)'s remaining pegging hand")
        precondition(state.peggingCount + card.rank.pipValue <= 31, "Playing \(card) would exceed 31")

        var next = state
        next.peggingRemaining[seat].removeAll { $0 == card }
        next.peggingPile.append(card)
        next.peggingCount += card.rank.pipValue
        next.lastCardPlayedBy = seat

        let events = peggingScoreForLatestPlay(pile: next.peggingPile, count: next.peggingCount, ruleset: next.ruleset)
        next.scores[seat] += events.reduce(0) { $0 + $1.points }

        if let winner = checkWinner(next) {
            next.winner = winner
            next.phase = .gameOver
            return next
        }

        if next.peggingCount == 31 {
            resetPeggingRun(&next)
            next.turnToAct = firstAvailableLeader(preferring: seat.opponent, in: next) ?? next.turnToAct
        } else if next.goSeat != nil {
            // Someone already said go this run — the count only went up since then, so
            // they're still stuck. The current player keeps leading rather than bouncing
            // the turn back to a seat that's guaranteed unable to act.
            next.turnToAct = seat
        } else {
            next.turnToAct = seat.opponent
        }

        if next.peggingRemaining.playerOne.isEmpty && next.peggingRemaining.playerTwo.isEmpty {
            next = beginCounting(next)
        }
        return next
    }

    private static func sayGo(_ state: GameState, seat: Seat) -> GameState {
        precondition(state.phase == .pegging, "Can only say go during pegging")
        precondition(state.turnToAct == seat, "It is not \(seat)'s turn to act")
        precondition(!canPlay(seat: seat, in: state), "\(seat) has a legal play and cannot say go")

        var next = state

        guard let firstGoSeat = state.goSeat else {
            // First "go" of this run: pass the turn to the opponent to see if they can continue.
            next.goSeat = seat
            next.turnToAct = seat.opponent
            return next
        }

        // Both seats have now said go this run — the run ends. Award the "go" point to
        // whoever played the last card, if any card was played in this run at all.
        if let scorer = next.lastCardPlayedBy {
            next.scores[scorer] += 1
        }
        resetPeggingRun(&next)
        next.turnToAct = firstAvailableLeader(preferring: firstGoSeat, in: next) ?? next.turnToAct

        if next.peggingRemaining.playerOne.isEmpty && next.peggingRemaining.playerTwo.isEmpty {
            next = beginCounting(next)
        }
        return next
    }

    private static func canPlay(seat: Seat, in state: GameState) -> Bool {
        state.peggingRemaining[seat].contains { state.peggingCount + $0.rank.pipValue <= 31 }
    }

    private static func firstAvailableLeader(preferring seat: Seat, in state: GameState) -> Seat? {
        if !state.peggingRemaining[seat].isEmpty { return seat }
        if !state.peggingRemaining[seat.opponent].isEmpty { return seat.opponent }
        return nil
    }

    private static func resetPeggingRun(_ state: inout GameState) {
        state.peggingPile = []
        state.peggingCount = 0
        state.goSeat = nil
        state.lastCardPlayedBy = nil
    }

    /// Scores whatever the most recently played card just formed: 15, 31, pairs (by
    /// trailing same-rank run length), and the longest trailing run of distinct,
    /// consecutive ranks. Unlike hand scoring, pegging only looks at contiguous
    /// suffixes of the pile, not every combination.
    static func peggingScoreForLatestPlay(pile: [Card], count: Int, ruleset: Ruleset) -> [ScoreEvent] {
        var events: [ScoreEvent] = []

        if count == 15 {
            events.append(ScoreEvent(kind: .fifteen, cards: pile, points: 2))
        }
        if count == 31 {
            events.append(ScoreEvent(kind: .thirtyOne, cards: pile, points: ruleset.exactThirtyOneScoresTwo ? 2 : 1))
        }

        if let lastRank = pile.last?.rank {
            var matchCount = 0
            for card in pile.reversed() {
                if card.rank == lastRank { matchCount += 1 } else { break }
            }
            if matchCount >= 2 {
                let points = matchCount * (matchCount - 1)
                events.append(ScoreEvent(kind: .pair, cards: Array(pile.suffix(matchCount)), points: points))
            }
        }

        if pile.count >= 3 {
            for length in stride(from: pile.count, through: 3, by: -1) {
                let suffix = pile.suffix(length)
                let ranks = suffix.map(\.rank.rawValue)
                guard Set(ranks).count == length,
                      let lo = ranks.min(), let hi = ranks.max(), hi - lo == length - 1 else {
                    continue
                }
                events.append(ScoreEvent(kind: .run, cards: Array(suffix), points: length))
                break
            }
        }

        return events
    }

    // MARK: - Counting

    private static func beginCounting(_ state: GameState) -> GameState {
        guard let starter = state.starter else { preconditionFailure("Starter must be set before counting") }
        guard let seed = state.currentSeed else { preconditionFailure("currentSeed must be set before counting") }

        var next = state
        let nonDealer = next.dealer.opponent

        let nonDealerBreakdown = Scorer.score(
            hand: next.hands[nonDealer], starter: starter, isCrib: false, ruleset: next.ruleset
        )
        next.scores[nonDealer] += nonDealerBreakdown.total

        var dealerBreakdown: ScoreBreakdown?
        var cribBreakdown: ScoreBreakdown?

        if checkWinner(next) == nil {
            let breakdown = Scorer.score(
                hand: next.hands[next.dealer], starter: starter, isCrib: false, ruleset: next.ruleset
            )
            next.scores[next.dealer] += breakdown.total
            dealerBreakdown = breakdown
        }
        if checkWinner(next) == nil {
            let breakdown = Scorer.score(hand: next.crib, starter: starter, isCrib: true, ruleset: next.ruleset)
            next.scores[next.dealer] += breakdown.total
            cribBreakdown = breakdown
        }

        next.lastRoundSummary = RoundSummary(
            nonDealerHand: nonDealerBreakdown,
            dealerHand: dealerBreakdown,
            crib: cribBreakdown,
            starter: starter,
            seed: seed
        )
        next.phase = .counting

        if let winner = checkWinner(next) {
            next.winner = winner
            next.phase = .gameOver
        }
        return next
    }

    private static func checkWinner(_ state: GameState) -> Seat? {
        if state.scores.playerOne >= state.ruleset.gameTarget { return .playerOne }
        if state.scores.playerTwo >= state.ruleset.gameTarget { return .playerTwo }
        return nil
    }
}
