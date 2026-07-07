/// Turns a state transition into spoken-language announcements for VoiceOver — see
/// docs/plan.md ("Accessibility"): async events with no visual focus target (the CPU's
/// turn, a "go," points scored) need proactive announcements, since VoiceOver only reads
/// what's currently focused. Pure and framework-free by design (no `UIAccessibility`
/// here) so it's fully testable with `swift test`; `AccessibilityAnnouncer` in
/// `CribbageUI` is the thin platform-specific layer that actually posts these.
///
/// Every announcement is written from `listenerSeat`'s point of view ("you"/"opponent")
/// and is careful never to reveal hidden information the listener wouldn't actually see —
/// the opponent's discarded cards are secret until the crib is counted, so those are
/// never named, only that a discard happened.
public enum AnnouncementBuilder {
    public static func announcements(before: GameState, after: GameState, move: Move, listenerSeat: Seat) -> [String] {
        var lines = moveDescription(before: before, after: after, move: move, listenerSeat: listenerSeat)

        if after.phase == .counting && before.phase != .counting {
            // The move that ends the play (a final card or a mutual go) can itself score —
            // e.g. a run plus "one for last card". Announce those play points explicitly
            // here, because the generic score-delta path is skipped on this transition (the
            // score jump also includes the about-to-be-counted hands, which would conflate).
            lines.append(contentsOf: finalPlayAnnouncements(before: before, after: after, listenerSeat: listenerSeat))
            if after.pendingCount == nil {
                lines.append(contentsOf: countingSummary(after, listenerSeat: listenerSeat))
            } else {
                // Muggins: don't read the hand totals aloud — the player has to count them.
                lines.append("Time to count. Claim your hand.")
            }
        } else {
            lines.append(contentsOf: scoreDeltaAnnouncements(before: before, after: after, listenerSeat: listenerSeat))
        }

        if after.phase == .gameOver && before.phase != .gameOver {
            lines.append(gameOverAnnouncement(after, listenerSeat: listenerSeat))
        }

        return lines
    }

    private static func moveDescription(
        before: GameState, after: GameState, move: Move, listenerSeat: Seat
    ) -> [String] {
        switch move {
        case .dealHand:
            return ["New hand dealt."]

        case .discard(let seat, let cards):
            // Your own discard is safe to read back; the opponent's is hidden information
            // until the crib is counted, so only the fact of it is announced.
            if seat == listenerSeat {
                let cardList = cards.map(\.spokenName).joined(separator: " and ")
                return ["You discarded \(cardList) to the crib."]
            }
            return ["Opponent discarded to the crib."]

        case .cutForStarter:
            guard let starter = after.starter else { return [] }
            var lines = ["Starter card: \(starter.spokenName)."]
            if starter.rank == .jack {
                let dealerIsListener = after.dealer == listenerSeat
                let heelsLine = dealerIsListener
                    ? "Jack! You score 2 for his heels."
                    : "Jack! Opponent scores 2 for his heels."
                lines.append(heelsLine)
            }
            return lines

        case .playCard(let seat, let card):
            let who = seat == listenerSeat ? "You" : "Opponent"
            return ["\(who) played \(card.spokenName). Count is \(after.peggingCount)."]

        case .sayGo(let seat):
            let who = seat == listenerSeat ? "You say" : "Opponent says"
            return ["\(who) Go."]

        case .claimScore(let seat, let points):
            let who = seat == listenerSeat ? "You count" : "Opponent counts"
            return ["\(who) \(points)."]

        case .callMuggins(let seat):
            return [seat == listenerSeat ? "You call muggins!" : "Opponent calls muggins!"]

        case .passMuggins(let seat):
            return [seat == listenerSeat ? "You pass on muggins." : "Opponent passes on muggins."]
        }
    }

    /// Generic score-delta narration — covers pegging points and "go"/31 bonuses
    /// uniformly, without needing to know *why* points were scored.
    private static func scoreDeltaAnnouncements(before: GameState, after: GameState, listenerSeat: Seat) -> [String] {
        Seat.allCases.compactMap { seat in
            let delta = after.scores[seat] - before.scores[seat]
            guard delta > 0 else { return nil }
            let who = seat == listenerSeat ? "You score" : "Opponent scores"
            return "\(who) \(delta) point\(delta == 1 ? "" : "s")."
        }
    }

    /// Points scored by the final play of the pegging phase, read off the per-seat
    /// `peggingEvents` accumulator (the newly appended tail since `before`).
    private static func finalPlayAnnouncements(before: GameState, after: GameState, listenerSeat: Seat) -> [String] {
        Seat.allCases.compactMap { seat in
            let alreadyAnnounced = before.peggingEvents[seat].count
            let newEvents = after.peggingEvents[seat].dropFirst(alreadyAnnounced)
            let points = newEvents.reduce(0) { $0 + $1.points }
            guard points > 0 else { return nil }
            let who = seat == listenerSeat ? "You score" : "Opponent scores"
            return "\(who) \(points) point\(points == 1 ? "" : "s") on the play."
        }
    }

    private static func countingSummary(_ state: GameState, listenerSeat: Seat) -> [String] {
        guard let summary = state.lastRoundSummary else { return [] }
        var lines: [String] = []

        let nonDealerIsListener = state.dealer.opponent == listenerSeat
        lines.append("\(nonDealerIsListener ? "Your" : "Opponent's") hand scores \(summary.nonDealerHand.total).")

        if let dealerHand = summary.dealerHand {
            lines.append("\(nonDealerIsListener ? "Opponent's" : "Your") hand scores \(dealerHand.total).")
        }
        if let crib = summary.crib {
            let dealerIsListener = state.dealer == listenerSeat
            lines.append("\(dealerIsListener ? "Your" : "Opponent's") crib scores \(crib.total).")
        }
        return lines
    }

    private static func gameOverAnnouncement(_ state: GameState, listenerSeat: Seat) -> String {
        guard let winner = state.winner else { return "Game over." }
        var line = winner == listenerSeat ? "You win!" : "Opponent wins."
        if let skunk = state.skunkResult, skunk != .normal {
            line += skunk == .doubleSkunk ? " Double skunk!" : " Skunk!"
        }
        return line
    }
}
