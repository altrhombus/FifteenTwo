/// The real CPU: uses `DiscardSolver`/`PeggingSolver` at every difficulty tier, sampling
/// from the top-*k* ranked options rather than falling back to a separate, unrelated
/// heuristic for easier play — see docs/plan.md ("One engine, three consumers").
public enum SolverCPU {
    public static func chooseDiscard<G: RandomNumberGenerator>(
        from hand: [Card],
        isDealer: Bool,
        difficulty: CPUDifficulty,
        ruleset: Ruleset = .standard,
        using rng: inout G
    ) -> [Card] {
        let options = DiscardSolver.bestDiscards(hand: hand, isDealer: isDealer, ruleset: ruleset)
        let topK = options.prefix(min(difficulty.discardTopK, options.count))
        let chosen = topK.randomElement(using: &rng) ?? options[0]
        return chosen.discarded
    }

    public static func choosePeggingPlay<G: RandomNumberGenerator>(
        mine: [Card],
        unseenCards: [Card],
        opponentCardCount: Int,
        pile: [Card],
        difficulty: CPUDifficulty,
        ruleset: Ruleset = .standard,
        using rng: inout G
    ) -> Card? {
        let ranked = PeggingSolver.rankedPlays(
            mine: mine,
            unseenCards: unseenCards,
            opponentCardCount: opponentCardCount,
            pile: pile,
            sampleCount: difficulty.peggingSampleCount,
            ruleset: ruleset,
            using: &rng
        )
        guard ranked[0].card != nil else { return nil } // no legal play — caller must say go
        let topK = ranked.prefix(min(difficulty.peggingTopK, ranked.count))
        let chosen = topK.randomElement(using: &rng) ?? ranked[0]
        return chosen.card
    }
}
