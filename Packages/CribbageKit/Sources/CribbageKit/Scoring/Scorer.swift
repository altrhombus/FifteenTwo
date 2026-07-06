/// Cribbage hand scoring, implemented against the official American Cribbage Congress
/// rules rather than from memory — see docs/plan.md ("Rules accuracy is non-negotiable").
///
/// Note on scope: "his heels" (2 points to the dealer when the cut starter is itself a
/// jack) is a cut-time bonus awarded once per deal, not part of scoring a made hand —
/// it belongs in `GameEngine` (Phase 3), not here.
public enum Scorer {
    /// Scores a 4-card hand (or crib) against the shared starter card.
    ///
    /// - Parameters:
    ///   - hand: Exactly 4 cards — a player's kept hand, or the crib.
    ///   - starter: The single shared starter/cut card.
    ///   - isCrib: The crib's flush rule differs from a hand's — see `scoreFlush`.
    public static func score(
        hand: [Card],
        starter: Card,
        isCrib: Bool,
        ruleset: Ruleset = .standard
    ) -> ScoreBreakdown {
        precondition(hand.count == 4, "A cribbage hand being scored must have exactly 4 cards, got \(hand.count)")

        let allCards = hand + [starter]
        return ScoreBreakdown(
            fifteens: scoreFifteens(allCards),
            pairs: scorePairs(allCards),
            runs: scoreRuns(allCards),
            flush: scoreFlush(hand: hand, starter: starter, isCrib: isCrib),
            nobs: scoreNobs(hand: hand, starter: starter)
        )
    }

    /// Every subset of 2+ cards whose pip values sum to exactly 15, each worth 2 points.
    /// Sums the subset before touching an array at all — this runs on the order of a
    /// million times per `DiscardSolver` call, so building a `[Card]` combo for every
    /// candidate subset (only to discard almost all of them) was the dominant cost.
    static func scoreFifteens(_ cards: [Card]) -> [ScoreEvent] {
        var events: [ScoreEvent] = []
        let pips = cards.map(\.rank.pipValue)
        let n = cards.count
        for mask in 1..<(1 << n) where mask.nonzeroBitCount >= 2 {
            var sum = 0
            for i in 0..<n where mask & (1 << i) != 0 {
                sum += pips[i]
            }
            guard sum == 15 else { continue }
            let combo = (0..<n).filter { mask & (1 << $0) != 0 }.map { cards[$0] }
            events.append(ScoreEvent(kind: .fifteen, cards: combo, points: 2))
        }
        return events
    }

    /// Every pair of cards sharing a rank, each worth 2 points (so three-of-a-kind is
    /// three separate pairs = 6 points, four-of-a-kind is six pairs = 12 points).
    static func scorePairs(_ cards: [Card]) -> [ScoreEvent] {
        var events: [ScoreEvent] = []
        for i in 0..<cards.count {
            for j in (i + 1)..<cards.count where cards[i].rank == cards[j].rank {
                events.append(ScoreEvent(kind: .pair, cards: [cards[i], cards[j]], points: 2))
            }
        }
        return events
    }

    /// The longest run of 3+ consecutive ranks, worth (run length × number of duplicate
    /// paths through it) points. E.g. 3,3,4,5,6 is a "double run of four": the run 3-4-5-6
    /// exists twice (once per 3), scoring 4 × 2 = 8 — on top of the pair of 3s separately.
    /// A 5-card hand can only ever contain one such maximal run, since two independent
    /// runs of 3+ would require at least 6 distinct ranks.
    static func scoreRuns(_ cards: [Card]) -> [ScoreEvent] {
        let grouped = Dictionary(grouping: cards, by: { $0.rank.rawValue })
        let distinctRanks = grouped.keys.sorted()
        guard !distinctRanks.isEmpty else { return [] }

        var bestRun: [Int] = []
        var current: [Int] = [distinctRanks[0]]
        for rank in distinctRanks.dropFirst() {
            if rank == current.last! + 1 {
                current.append(rank)
            } else {
                if current.count > bestRun.count { bestRun = current }
                current = [rank]
            }
        }
        if current.count > bestRun.count { bestRun = current }

        guard bestRun.count >= 3 else { return [] }

        let involvedCards = bestRun.flatMap { grouped[$0] ?? [] }
        let instances = bestRun.reduce(1) { $0 * (grouped[$1]?.count ?? 0) }
        return [ScoreEvent(kind: .run, cards: involvedCards, points: bestRun.count * instances)]
    }

    /// A hand flush needs only its 4 cards to match suit (5 if the starter also matches).
    /// A crib flush is stricter: without the starter also matching, it scores nothing at
    /// all — a classic cribbage-engine bug if not special-cased.
    static func scoreFlush(hand: [Card], starter: Card, isCrib: Bool) -> [ScoreEvent] {
        guard let firstSuit = hand.first?.suit, hand.allSatisfy({ $0.suit == firstSuit }) else {
            return []
        }
        if starter.suit == firstSuit {
            return [ScoreEvent(kind: .flush, cards: hand + [starter], points: 5)]
        }
        if isCrib {
            return []
        }
        return [ScoreEvent(kind: .flush, cards: hand, points: 4)]
    }

    /// "His nobs": 1 point if the hand (or crib) holds the jack matching the starter's suit.
    static func scoreNobs(hand: [Card], starter: Card) -> [ScoreEvent] {
        guard let jack = hand.first(where: { $0.rank == .jack && $0.suit == starter.suit }) else {
            return []
        }
        return [ScoreEvent(kind: .nobs, cards: [jack, starter], points: 1)]
    }
}
