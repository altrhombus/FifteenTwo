import Observation
import CribbageKit

/// Drives a solo game against `NaiveCPU`. Every human action and every CPU reaction goes
/// through the same `GameEngine.reduce` — see docs/plan.md ("One engine, three consumers").
/// This lives in `CribbageUI` (not an app target) so macOS can reuse it unchanged in
/// Phase 9 rather than duplicating session logic per platform.
@Observable
public final class GameSessionController {
    public private(set) var state: GameState
    public let humanSeat: Seat
    private let ruleset: Ruleset
    private var cpuRNG: SeededGenerator

    public init(humanSeat: Seat = .playerOne, ruleset: Ruleset = .standard, seed: UInt64 = .random(in: .min ... .max)) {
        self.state = GameState(ruleset: ruleset, dealer: humanSeat, seed: seed)
        self.humanSeat = humanSeat
        self.ruleset = ruleset
        self.cpuRNG = SeededGenerator(seed: seed &+ 1)
    }

    public var cpuSeat: Seat { humanSeat.opponent }

    public func startGame() {
        apply(.dealHand)
    }

    public func newGame() {
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
        performCPUMoveIfNeeded()
    }

    private func performCPUMoveIfNeeded() {
        switch state.phase {
        case .discarding where state.hands[cpuSeat].count == 6:
            let discard = NaiveCPU.chooseDiscard(from: state.hands[cpuSeat], using: &cpuRNG)
            apply(.discard(seat: cpuSeat, cards: discard))
        case .pegging where state.turnToAct == cpuSeat:
            let legal = GameEngine.legalPlays(for: cpuSeat, in: state)
            if let card = NaiveCPU.choosePeggingPlay(from: legal, using: &cpuRNG) {
                apply(.playCard(seat: cpuSeat, card: card))
            } else {
                apply(.sayGo(seat: cpuSeat))
            }
        default:
            break
        }
    }
}
