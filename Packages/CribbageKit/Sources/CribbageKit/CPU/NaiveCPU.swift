/// Placeholder CPU behavior: picks uniformly at random among legal choices. Phase 4
/// replaces this with `DiscardSolver`/`PeggingSolver` — see docs/plan.md ("CPU difficulty
/// tiers, not just optimal"). This exists now purely to make the Phase 3 game loop
/// playable end to end.
public enum NaiveCPU {
    public static func chooseDiscard<G: RandomNumberGenerator>(from hand: [Card], using rng: inout G) -> [Card] {
        Array(hand.shuffled(using: &rng).prefix(2))
    }

    public static func choosePeggingPlay<G: RandomNumberGenerator>(
        from legalPlays: [Card], using rng: inout G
    ) -> Card? {
        legalPlays.randomElement(using: &rng)
    }
}
