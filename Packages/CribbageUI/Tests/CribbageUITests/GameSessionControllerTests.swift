import Testing
import CribbageKit
@testable import CribbageUI

/// Drives full games end to end through `GameSessionController` — the same entry points
/// the real UI calls — making the human seat play randomly-but-legally, same as the CPU.
/// This is the integration check that the reducer, the CPU automation, and the session
/// controller's move-application all cooperate correctly across a whole game, not just
/// the isolated `GameEngine` unit tests.
struct GameSessionControllerTests {
    @Test func playsFullGamesToCompletionWithoutViolatingAnyPrecondition() {
        for seed in UInt64(0)..<20 {
            let controller = GameSessionController(humanSeat: .playerOne, seed: seed)
            var rng = SeededGenerator(seed: seed &+ 1000)
            var safetyCounter = 0

            while controller.state.phase != .gameOver {
                safetyCounter += 1
                #expect(safetyCounter < 5000, "Game did not terminate — possible stuck state at seed \(seed)")
                guard safetyCounter < 5000 else { break }

                performOneStep(controller: controller, rng: &rng)
            }

            #expect(controller.state.phase == .gameOver)
            #expect(controller.state.winner != nil)
            #expect(controller.state.scores[controller.state.winner!] >= controller.state.ruleset.gameTarget)
        }
    }

    private func performOneStep(controller: GameSessionController, rng: inout SeededGenerator) {
        switch controller.state.phase {
        case .dealing:
            controller.startGame()
        case .discarding:
            guard controller.state.hands[controller.humanSeat].count == 6 else { return }
            let hand = controller.state.hands[controller.humanSeat]
            controller.discard(NaiveCPU.chooseDiscard(from: hand, using: &rng))
        case .cutStarter:
            controller.cutForStarter()
        case .pegging:
            guard controller.state.turnToAct == controller.humanSeat else { return }
            if let card = NaiveCPU.choosePeggingPlay(from: controller.legalHumanPlays, using: &rng) {
                controller.play(card)
            } else {
                controller.sayGo()
            }
        case .counting:
            controller.dealNextHand()
        case .gameOver:
            break
        }
    }
}
