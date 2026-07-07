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
        case .claimScore(let seat, let points):
            return claimScore(state, seat: seat, points: points)
        case .callMuggins(let seat):
            return resolveMuggins(state, seat: seat, take: true)
        case .passMuggins(let seat):
            return resolveMuggins(state, seat: seat, take: false)
        }
    }

    /// Cards `seat` may legally play right now (empty if it isn't their turn, or the
    /// phase isn't pegging).
    public static func legalPlays(for seat: Seat, in state: GameState) -> [Card] {
        guard state.phase == .pegging, state.turnToAct == seat else { return [] }
        return state.peggingRemaining[seat].filter { state.peggingCount + $0.rank.pipValue <= 31 }
    }

    /// Which seat needs to act next, in the strictly-serialized sense async play (Game
    /// Center turn-based matches) needs — `nil` once the game is over. Solo and live
    /// multiplayer don't need this: pegging already has `state.turnToAct`, and discarding
    /// there allows both seats to act "simultaneously" since there's an always-on
    /// connection. A store-and-forward match can only ever have one active participant,
    /// so discarding (and every other phase) needs a strict order here — reusing the same
    /// dealer-deals/non-dealer-cuts convention already established for live multiplayer's
    /// one-shot moves, just applied consistently to discarding too.
    public static func seatToActNext(in state: GameState) -> Seat? {
        switch state.phase {
        case .dealing:
            return state.dealer
        case .discarding:
            let nonDealer = state.dealer.opponent
            return state.hands[nonDealer].count == 6 ? nonDealer : state.dealer
        case .cutStarter:
            return state.dealer.opponent
        case .pegging:
            return state.turnToAct
        case .counting:
            // Muggins makes the show interactive: whoever owes the current claim or
            // muggins decision acts. Once counting is done (or muggins is off), the dealer
            // is next — they deal the following hand.
            return state.pendingCount?.actor ?? state.dealer
        case .gameOver:
            return nil
        }
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
        next.peggingEvents = PerSeat(playerOne: [], playerTwo: [])
        next.hisHeelsEvent = nil
        next.pendingCount = nil
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
            let heels = ScoreEvent(kind: .hisHeels, cards: [starter], points: 2) // "his heels"
            next.scores[next.dealer] += heels.points
            next.hisHeelsEvent = heels
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
        next.peggingEvents[seat].append(contentsOf: events)

        let bothHandsEmpty = next.peggingRemaining.playerOne.isEmpty && next.peggingRemaining.playerTwo.isEmpty

        // "One for last card": whoever plays the final card of the pegging phase pegs 1,
        // unless that card made exactly 31 (which already scored 2). Without this the last
        // player is short-changed on nearly every hand — the play almost always ends by a
        // legal final card rather than a mutual "go" (which is handled in `sayGo`).
        if bothHandsEmpty && next.peggingCount != 31 {
            let lastCard = ScoreEvent(kind: .go, cards: [card], points: 1)
            next.scores[seat] += lastCard.points
            next.peggingEvents[seat].append(lastCard)
        }

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
            let goEvent = ScoreEvent(kind: .go, cards: next.peggingPile.last.map { [$0] } ?? [], points: 1)
            next.scores[scorer] += goEvent.points
            next.peggingEvents[scorer].append(goEvent)
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

        if next.ruleset.mugginsEnabled {
            // Interactive show: award nothing automatically. Compute all three true values
            // now — for the itemized summary and so the player can check their own count —
            // then hand control to the non-dealer to claim their hand first. Points are
            // awarded by the `.claimScore`/`.callMuggins` moves that follow.
            let dealerBreakdown = Scorer.score(
                hand: next.hands[next.dealer], starter: starter, isCrib: false, ruleset: next.ruleset
            )
            let cribBreakdown = Scorer.score(hand: next.crib, starter: starter, isCrib: true, ruleset: next.ruleset)
            next.lastRoundSummary = RoundSummary(
                nonDealerHand: nonDealerBreakdown,
                dealerHand: dealerBreakdown,
                crib: cribBreakdown,
                starter: starter,
                seed: seed,
                hisHeels: next.hisHeelsEvent,
                nonDealerPegging: next.peggingEvents[nonDealer],
                dealerPegging: next.peggingEvents[next.dealer]
            )
            next.phase = .counting
            next.pendingCount = PendingCount(
                item: .nonDealerHand, owner: nonDealer, trueValue: nonDealerBreakdown.total
            )
            return next
        }

        // Automatic counting (muggins off): score in order, stopping the instant someone
        // reaches the target — a player can win on their hand before the crib is ever counted.
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
            seed: seed,
            hisHeels: next.hisHeelsEvent,
            nonDealerPegging: next.peggingEvents[nonDealer],
            dealerPegging: next.peggingEvents[next.dealer]
        )
        next.phase = .counting

        if let winner = checkWinner(next) {
            next.winner = winner
            next.phase = .gameOver
        }
        return next
    }

    // MARK: - Muggins (interactive counting)

    private static func claimScore(_ state: GameState, seat: Seat, points: Int) -> GameState {
        precondition(state.phase == .counting, "Can only claim a score during counting")
        guard let pending = state.pendingCount else {
            preconditionFailure("No counting item is awaiting a claim")
        }
        precondition(pending.stage == .awaitingClaim, "The current counting item is not awaiting a claim")
        precondition(seat == pending.owner, "Only \(pending.owner) may claim \(pending.item)")

        var next = state
        let award = max(0, min(points, pending.trueValue))
        next.scores[seat] += award

        if let winner = checkWinner(next) {
            next.winner = winner
            next.phase = .gameOver
            next.pendingCount = nil
            return next
        }

        let shortfall = pending.trueValue - award
        if shortfall > 0 {
            var updated = pending
            updated.stage = .awaitingMuggins
            updated.shortfall = shortfall
            next.pendingCount = updated
            return next
        }
        return advanceCounting(next, after: pending.item)
    }

    private static func resolveMuggins(_ state: GameState, seat: Seat, take: Bool) -> GameState {
        precondition(state.phase == .counting, "Can only resolve muggins during counting")
        guard let pending = state.pendingCount else {
            preconditionFailure("No counting item is awaiting a muggins decision")
        }
        precondition(pending.stage == .awaitingMuggins, "The current counting item is not awaiting a muggins call")
        precondition(seat == pending.owner.opponent, "Only \(pending.owner.opponent) may muggins \(pending.item)")

        var next = state
        if take {
            next.scores[seat] += pending.shortfall
            if let winner = checkWinner(next) {
                next.winner = winner
                next.phase = .gameOver
                next.pendingCount = nil
                return next
            }
        }
        return advanceCounting(next, after: pending.item)
    }

    /// Moves the interactive show to the next item in official order, or ends it once the
    /// crib has been counted.
    private static func advanceCounting(_ state: GameState, after item: CountingItem) -> GameState {
        guard let starter = state.starter else { preconditionFailure("Starter must be set during counting") }
        var next = state

        switch item {
        case .nonDealerHand:
            let dealerValue = Scorer.score(
                hand: next.hands[next.dealer], starter: starter, isCrib: false, ruleset: next.ruleset
            ).total
            next.pendingCount = PendingCount(item: .dealerHand, owner: next.dealer, trueValue: dealerValue)
        case .dealerHand:
            let cribValue = Scorer.score(
                hand: next.crib, starter: starter, isCrib: true, ruleset: next.ruleset
            ).total
            next.pendingCount = PendingCount(item: .crib, owner: next.dealer, trueValue: cribValue)
        case .crib:
            next.pendingCount = nil // the show is complete
        }
        return next
    }

    private static func checkWinner(_ state: GameState) -> Seat? {
        if state.scores.playerOne >= state.ruleset.gameTarget { return .playerOne }
        if state.scores.playerTwo >= state.ruleset.gameTarget { return .playerTwo }
        return nil
    }
}
