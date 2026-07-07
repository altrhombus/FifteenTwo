/// The three scored items of the show, in official counting order. Only used when
/// `Ruleset.mugginsEnabled` — with muggins off, counting is fully automatic and no
/// `PendingCount` is ever created.
public enum CountingItem: String, Codable, Sendable, CaseIterable {
    case nonDealerHand
    case dealerHand
    case crib
}

/// Tracks the one counting decision currently owed during a muggins-enabled show: either
/// the item's owner still has to claim their points, or (having under-claimed) their
/// opponent has an open window to "muggins" the missed points.
public struct PendingCount: Codable, Equatable, Sendable {
    public enum Stage: String, Codable, Sendable {
        /// `owner` must declare what they think the item is worth (`.claimScore`).
        case awaitingClaim
        /// `owner` under-claimed by `shortfall`; `owner.opponent` may `.callMuggins`
        /// to peg those points, or `.passMuggins` to let them go.
        case awaitingMuggins
    }

    public var item: CountingItem
    /// Who counts this item: the non-dealer for their hand, the dealer for their hand and
    /// the crib.
    public var owner: Seat
    /// The item's actual score — the ceiling on what `owner` can be awarded, and the basis
    /// for the muggins shortfall.
    public var trueValue: Int
    public var stage: Stage
    /// How much `owner` left unclaimed, available to muggins. Only meaningful in
    /// `.awaitingMuggins`.
    public var shortfall: Int

    public init(item: CountingItem, owner: Seat, trueValue: Int, stage: Stage = .awaitingClaim, shortfall: Int = 0) {
        self.item = item
        self.owner = owner
        self.trueValue = trueValue
        self.stage = stage
        self.shortfall = shortfall
    }

    /// The seat whose turn it is to act on this pending count.
    public var actor: Seat {
        stage == .awaitingClaim ? owner : owner.opponent
    }
}
