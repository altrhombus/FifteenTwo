#if !os(watchOS)
import Observation
import CribbageKit

/// The human's discard, ranked against every option `DiscardSolver` considered — the
/// post-hand training breakdown per docs/plan.md ("post-game breakdown ... showing
/// expected value of every discard choice").
public struct DiscardAnalysis: Equatable, Sendable {
    public let options: [DiscardOption] // all 15, sorted best first
    public let chosen: [Card]

    public var chosenOption: DiscardOption? {
        options.first { Set($0.discarded) == Set(chosen) }
    }

    public var bestOption: DiscardOption? { options.first }
}

/// Drives a solo game against `SolverCPU`. Every human action and every CPU reaction goes
/// through the same `GameEngine.reduce` — see docs/plan.md ("One engine, three consumers").
/// This lives in `CribbageUI` (not an app target) so macOS can reuse it unchanged in
/// Phase 9 rather than duplicating session logic per platform.
///
/// CPU moves run off the main actor: a discard analysis is ~684,000 `Scorer` calls and
/// takes over a second even in a release build, which would otherwise freeze the UI.
@Observable
@MainActor
public final class GameSessionController {
    public private(set) var state: GameState
    public let humanSeat: Seat
    public var difficulty: CPUDifficulty
    public private(set) var isCPUThinking = false
    public private(set) var lastDiscardAnalysis: DiscardAnalysis?
    /// Settable (not just set at init) so a Settings change can take effect on the next
    /// `newGame()`/`dealNextHand()` — it deliberately doesn't retroactively alter a hand
    /// already in progress, since `state` only picks up the current value the next time
    /// it's reconstructed.
    public var ruleset: Ruleset
    /// The CPU's own move-sampling randomness — deliberately independent of the per-hand
    /// deal `Seed256`, which is the one that matters for fairness/replay (see
    /// docs/plan.md, "RNG & Fairness"). Nothing about how the CPU plays needs to be
    /// reproducible to the player.
    private var cpuRNG: SeededGenerator
    private var cpuTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?

    public init(
        humanSeat: Seat = .playerOne,
        difficulty: CPUDifficulty = .intermediate,
        ruleset: Ruleset = .standard
    ) {
        self.state = GameState(ruleset: ruleset, dealer: humanSeat)
        self.humanSeat = humanSeat
        self.difficulty = difficulty
        self.ruleset = ruleset
        self.cpuRNG = SeededGenerator(seed: .random(in: .min ... .max))
    }

    public var cpuSeat: Seat { humanSeat.opponent }

    public func startGame() {
        apply(.dealHand(seed: .random()))
    }

    public func newGame() {
        cpuTask?.cancel()
        analysisTask?.cancel()
        lastDiscardAnalysis = nil
        state = GameState(ruleset: ruleset, dealer: humanSeat)
        cpuRNG = SeededGenerator(seed: .random(in: .min ... .max))
        startGame()
    }

    /// "Practice this exact hand again" — see docs/plan.md's RNG & Fairness section: the
    /// deal is entirely determined by its seed, so replaying it is just dealing again
    /// with the same one. This starts a fresh practice attempt (scores reset to 0) rather
    /// than resuming the prior game, since it's a training tool for this specific hand's
    /// decisions, not a way to undo a result.
    public func practiceThisHandAgain() {
        guard let seed = state.lastRoundSummary?.seed else { return }
        cpuTask?.cancel()
        analysisTask?.cancel()
        lastDiscardAnalysis = nil
        state = GameState(ruleset: ruleset, dealer: humanSeat)
        cpuRNG = SeededGenerator(seed: .random(in: .min ... .max))
        apply(.dealHand(seed: seed))
    }

    public func discard(_ cards: [Card]) {
        let handBeforeDiscard = state.hands[humanSeat]
        let isDealer = state.dealer == humanSeat
        apply(.discard(seat: humanSeat, cards: cards))
        scheduleDiscardAnalysis(hand: handBeforeDiscard, chosen: cards, isDealer: isDealer)
    }

    public func cutForStarter() {
        apply(.cutForStarter)
    }

    public func play(_ card: Card) {
        apply(.playCard(seat: humanSeat, card: card))
    }

    public func sayGo() {
        apply(.sayGo(seat: humanSeat))
    }

    public func dealNextHand() {
        lastDiscardAnalysis = nil
        apply(.dealHand(seed: .random()))
    }

    public var legalHumanPlays: [Card] {
        GameEngine.legalPlays(for: humanSeat, in: state)
    }

    private func apply(_ move: Move) {
        let previous = state
        state = GameEngine.reduce(state, applying: move)
        AccessibilityAnnouncer.announce(before: previous, after: state, move: move, listenerSeat: humanSeat)
        reportGameCenterProgressIfNeeded(previous: previous)
        scheduleCPUMoveIfNeeded()
    }

    /// Compares against `previous` rather than switching on `move`/`state.phase` directly,
    /// since a hand can end the game in the same `reduce` call that scores it — phase
    /// sometimes jumps straight from `.pegging` to `.gameOver` with no visible `.counting`
    /// step in between, so "did lastRoundSummary just change" is the reliable signal.
    private func reportGameCenterProgressIfNeeded(previous: GameState) {
        if let summary = state.lastRoundSummary, summary != previous.lastRoundSummary {
            GameCenterReporter.reportHandCounted(summary, dealer: state.dealer, humanSeat: humanSeat)
        }
        if previous.phase != .gameOver, state.phase == .gameOver, let winner = state.winner {
            GameCenterReporter.reportSoloGameCompleted(
                winner: winner, humanSeat: humanSeat, skunkResult: state.skunkResult
            )
        }
    }

    /// Runs the same `DiscardSolver` analysis used for CPU moves against the human's own
    /// hand, so the post-hand summary can show what was left on the table — independent
    /// of `cpuTask` since this doesn't gate any game-state transition.
    private func scheduleDiscardAnalysis(hand: [Card], chosen: [Card], isDealer: Bool) {
        let rulesetSnapshot = ruleset
        analysisTask = Task {
            let options = await Task.detached(priority: .utility) {
                DiscardSolver.bestDiscards(hand: hand, isDealer: isDealer, ruleset: rulesetSnapshot)
            }.value
            guard !Task.isCancelled else { return }
            lastDiscardAnalysis = DiscardAnalysis(options: options, chosen: chosen)
        }
    }

    private var cpuNeedsToAct: Bool {
        switch state.phase {
        case .discarding: state.hands[cpuSeat].count == 6
        case .pegging: state.turnToAct == cpuSeat
        default: false
        }
    }

    private func scheduleCPUMoveIfNeeded() {
        guard cpuNeedsToAct else { return }

        let snapshot = state
        let seat = cpuSeat
        let diff = difficulty
        let rulesetSnapshot = ruleset
        let rngSnapshot = cpuRNG

        isCPUThinking = true
        cpuTask = Task {
            let (move, advancedRNG) = await Task.detached(priority: .userInitiated) {
                Self.computeCPUMove(
                    state: snapshot, seat: seat, difficulty: diff, ruleset: rulesetSnapshot, rng: rngSnapshot
                )
            }.value

            guard !Task.isCancelled else { return }
            cpuRNG = advancedRNG
            isCPUThinking = false
            apply(move)
        }
    }

    private nonisolated static func computeCPUMove(
        state: GameState, seat: Seat, difficulty: CPUDifficulty, ruleset: Ruleset, rng: SeededGenerator
    ) -> (Move, SeededGenerator) {
        var rng = rng
        switch state.phase {
        case .discarding:
            let discard = SolverCPU.chooseDiscard(
                from: state.hands[seat],
                isDealer: seat == state.dealer,
                difficulty: difficulty,
                ruleset: ruleset,
                using: &rng
            )
            return (.discard(seat: seat, cards: discard), rng)

        case .pegging:
            let unseen = Deck.standard52.filter {
                !state.peggingRemaining[seat].contains($0) && $0 != state.starter && !state.peggingPile.contains($0)
            }
            let card = SolverCPU.choosePeggingPlay(
                mine: state.peggingRemaining[seat],
                unseenCards: unseen,
                opponentCardCount: state.peggingRemaining[seat.opponent].count,
                pile: state.peggingPile,
                difficulty: difficulty,
                ruleset: ruleset,
                using: &rng
            )
            if let card {
                return (.playCard(seat: seat, card: card), rng)
            } else {
                return (.sayGo(seat: seat), rng)
            }

        default:
            preconditionFailure("computeCPUMove called outside the discarding/pegging phases")
        }
    }
}
#endif
