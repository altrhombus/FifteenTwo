/// Pegging analysis — see docs/plan.md ("Pegging solver — exact where both hands are
/// known, expectation-optimal where they aren't"). Both entry points share the same
/// minimax core and the same `GameEngine.peggingScoreForLatestPlay` scoring function —
/// only the turn-passing/"go" bookkeeping is reimplemented here, in a representation
/// suited to recursive search rather than move-by-move reduction. That duplication was
/// worth watching closely: designing this surfaced a real turn-passing bug in
/// `GameEngine` itself (fixed separately), so the rules below are deliberately written
/// to match the corrected `GameEngine` behavior exactly.
public enum PeggingSolver {
    /// Exact minimax — both hands are fully known (post-game analysis, "practice this
    /// hand again" replay). The objective is net margin (my points minus theirs) from
    /// this point to the end of pegging, not a full-game win-probability estimate.
    public static func bestPlay(
        mine: [Card], theirs: [Card], pile: [Card], ruleset: Ruleset = .standard
    ) -> PeggingOption {
        let count = pile.reduce(0) { $0 + $1.rank.pipValue }
        let state = SearchState(
            mine: mine, theirs: theirs, pile: pile, count: count,
            turnIsMine: true, goSeat: nil, lastPlayWasMine: nil
        )

        let legal = state.mine.filter { state.count + $0.rank.pipValue <= 31 }
        guard !legal.isEmpty else {
            return PeggingOption(card: nil, netScore: valueAfterGo(state, iAmGoing: true, ruleset: ruleset))
        }
        var best: (Card?, Int) = (nil, Int.min)
        for card in legal {
            let value = valueAfterPlay(card, from: state, mine: true, ruleset: ruleset)
            if value > best.1 { best = (card, value) }
        }
        return PeggingOption(card: best.0, netScore: best.1)
    }

    /// Live CPU decision — the opponent's hand is genuinely hidden. Samples plausible
    /// opponent hands from the unseen cards and averages the same minimax core over
    /// those samples, rather than exhaustively enumerating all ~100,000 possibilities
    /// (see docs/plan.md's complexity note) — this keeps play imperceptibly fast while
    /// still being expectation-optimal under a correct probability model.
    public static func bestPlay<G: RandomNumberGenerator>(
        mine: [Card],
        unseenCards: [Card],
        opponentCardCount: Int,
        pile: [Card],
        sampleCount: Int = 150,
        ruleset: Ruleset = .standard,
        using rng: inout G
    ) -> PeggingOption {
        let count = pile.reduce(0) { $0 + $1.rank.pipValue }
        let legal = mine.filter { count + $0.rank.pipValue <= 31 }
        guard !legal.isEmpty else {
            return PeggingOption(card: nil, netScore: 0)
        }
        guard unseenCards.count >= opponentCardCount, opponentCardCount > 0 else {
            // No information to sample from (or opponent holds nothing) — fall back to
            // the best card against an empty hypothetical hand.
            return bestPlay(mine: mine, theirs: [], pile: pile, ruleset: ruleset)
        }

        var totals: [Card: Int] = [:]
        for card in legal { totals[card] = 0 }

        for _ in 0..<sampleCount {
            let sampledOpponentHand = Array(unseenCards.shuffled(using: &rng).prefix(opponentCardCount))
            let state = SearchState(
                mine: mine, theirs: sampledOpponentHand, pile: pile, count: count,
                turnIsMine: true, goSeat: nil, lastPlayWasMine: nil
            )
            for card in legal {
                totals[card, default: 0] += valueAfterPlay(card, from: state, mine: true, ruleset: ruleset)
            }
        }

        let best = legal.max { (totals[$0] ?? 0) < (totals[$1] ?? 0) }
        let bestTotal = best.flatMap { totals[$0] } ?? 0
        return PeggingOption(card: best, netScore: Int((Double(bestTotal) / Double(sampleCount)).rounded()))
    }

    // MARK: - Shared minimax core

    private struct SearchState {
        var mine: [Card]
        var theirs: [Card]
        var pile: [Card]
        var count: Int
        var turnIsMine: Bool
        /// `true` if I said go first this run, `false` if they did, `nil` if neither has yet.
        var goSeat: Bool?
        var lastPlayWasMine: Bool?
    }

    private static func value(_ state: SearchState, ruleset: Ruleset) -> Int {
        if state.mine.isEmpty && state.theirs.isEmpty { return 0 }

        if state.turnIsMine {
            let legal = state.mine.filter { state.count + $0.rank.pipValue <= 31 }
            guard !legal.isEmpty else {
                return valueAfterGo(state, iAmGoing: true, ruleset: ruleset)
            }
            return legal.map { valueAfterPlay($0, from: state, mine: true, ruleset: ruleset) }.max() ?? 0
        } else {
            let legal = state.theirs.filter { state.count + $0.rank.pipValue <= 31 }
            guard !legal.isEmpty else {
                return valueAfterGo(state, iAmGoing: false, ruleset: ruleset)
            }
            return legal.map { valueAfterPlay($0, from: state, mine: false, ruleset: ruleset) }.min() ?? 0
        }
    }

    private static func valueAfterPlay(_ card: Card, from state: SearchState, mine: Bool, ruleset: Ruleset) -> Int {
        var next = state
        if mine {
            next.mine.removeAll { $0 == card }
        } else {
            next.theirs.removeAll { $0 == card }
        }
        next.pile.append(card)
        next.count += card.rank.pipValue
        next.lastPlayWasMine = mine

        let events = GameEngine.peggingScoreForLatestPlay(pile: next.pile, count: next.count, ruleset: ruleset)
        let points = events.reduce(0) { $0 + $1.points }
        let signedPoints = mine ? points : -points

        if next.count == 31 {
            next.pile = []
            next.count = 0
            next.goSeat = nil
            next.turnIsMine = leader(preferMine: !mine, mine: next.mine, theirs: next.theirs)
        } else if next.goSeat != nil {
            // Matches the corrected GameEngine rule: once someone has said go this run,
            // the current player keeps leading rather than bouncing the turn back.
            next.turnIsMine = mine
        } else {
            next.turnIsMine = !mine
        }

        return signedPoints + value(next, ruleset: ruleset)
    }

    private static func valueAfterGo(_ state: SearchState, iAmGoing: Bool, ruleset: Ruleset) -> Int {
        var next = state
        guard let firstGoWasMine = next.goSeat else {
            next.goSeat = iAmGoing
            next.turnIsMine = !iAmGoing
            return value(next, ruleset: ruleset)
        }

        // Both sides have now said go — the run ends.
        var points = 0
        if let lastMine = next.lastPlayWasMine {
            points = lastMine ? 1 : -1
        }
        next.pile = []
        next.count = 0
        next.goSeat = nil
        next.turnIsMine = leader(preferMine: firstGoWasMine, mine: next.mine, theirs: next.theirs)
        return points + value(next, ruleset: ruleset)
    }

    private static func leader(preferMine: Bool, mine: [Card], theirs: [Card]) -> Bool {
        if preferMine && !mine.isEmpty { return true }
        if !preferMine && !theirs.isEmpty { return false }
        return !mine.isEmpty
    }
}
