import Observation
import CribbageKit

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
    private let ruleset: Ruleset
    private var cpuRNG: SeededGenerator
    private var cpuTask: Task<Void, Never>?

    public init(
        humanSeat: Seat = .playerOne,
        difficulty: CPUDifficulty = .intermediate,
        ruleset: Ruleset = .standard,
        seed: UInt64 = .random(in: .min ... .max)
    ) {
        self.state = GameState(ruleset: ruleset, dealer: humanSeat, seed: seed)
        self.humanSeat = humanSeat
        self.difficulty = difficulty
        self.ruleset = ruleset
        self.cpuRNG = SeededGenerator(seed: seed &+ 1)
    }

    public var cpuSeat: Seat { humanSeat.opponent }

    public func startGame() {
        apply(.dealHand)
    }

    public func newGame() {
        cpuTask?.cancel()
        state = GameState(ruleset: ruleset, dealer: humanSeat, seed: .random(in: .min ... .max))
        cpuRNG = SeededGenerator(seed: state.seed &+ 1)
        startGame()
    }

    public func discard(_ cards: [Card]) {
        apply(.discard(seat: humanSeat, cards: cards))
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
        apply(.dealHand)
    }

    public var legalHumanPlays: [Card] {
        GameEngine.legalPlays(for: humanSeat, in: state)
    }

    private func apply(_ move: Move) {
        state = GameEngine.reduce(state, applying: move)
        scheduleCPUMoveIfNeeded()
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
