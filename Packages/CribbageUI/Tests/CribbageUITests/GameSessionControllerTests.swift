import Testing
import CribbageKit
@testable import CribbageUI

/// Drives full games end to end through `GameSessionController` — the same entry points
/// the real UI calls — making the human seat play randomly-but-legally, same as the CPU.
/// This is the integration check that the reducer, the CPU automation, and the session
/// controller's move-application all cooperate correctly across a whole game, not just
/// the isolated `GameEngine` unit tests.
///
/// The CPU now runs the real solvers asynchronously (see GameSessionController's doc
/// comment on why), so this test awaits `isCPUThinking` going false after every human
/// move rather than looping synchronously. Only 2 games are run here — a discard
/// analysis is ~684,000 Scorer calls, so a full game's worth of CPU discards is the
/// dominant cost, unlike the old NaiveCPU-backed version of this test.
@MainActor
struct GameSessionControllerTests {
    @Test func playsFullGamesToCompletionWithoutViolatingAnyPrecondition() async {
        for seed in UInt64(0)..<2 {
            let controller = GameSessionController(humanSeat: .playerOne, difficulty: .beginner, seed: seed)
            var rng = SeededGenerator(seed: seed &+ 1000)
            var safetyCounter = 0

            while controller.state.phase != .gameOver {
                safetyCounter += 1
                #expect(safetyCounter < 500, "Game did not terminate — possible stuck state at seed \(seed)")
                guard safetyCounter < 500 else { break }

                await performOneStep(controller: controller, rng: &rng)
            }

            #expect(controller.state.phase == .gameOver)
            #expect(controller.state.winner != nil)
            #expect(controller.state.scores[controller.state.winner!] >= controller.state.ruleset.gameTarget)
        }
    }

    private func performOneStep(controller: GameSessionController, rng: inout SeededGenerator) async {
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
            return
        }
        await waitForCPU(controller)
    }

    private func waitForCPU(_ controller: GameSessionController) async {
        while controller.isCPUThinking {
            await Task.yield()
        }
    }

    @Test func humanDiscardPopulatesTheTrainingAnalysis() async {
        let controller = GameSessionController(humanSeat: .playerOne, difficulty: .beginner, seed: 123)
        controller.startGame()
        await waitForCPU(controller) // let the CPU discard first, doesn't affect this check

        let hand = controller.state.hands[controller.humanSeat]
        let discarded = Array(hand.prefix(2))
        controller.discard(discarded)

        var waited = 0
        while controller.lastDiscardAnalysis == nil, waited < 400 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms — real elapsed time, unlike Task.yield()
            waited += 1
        }

        let analysis = controller.lastDiscardAnalysis
        #expect(analysis != nil)
        #expect(analysis?.options.count == 15)
        #expect(Set(analysis?.chosen ?? []) == Set(discarded))
        #expect(analysis?.chosenOption != nil)
        #expect(analysis?.bestOption == analysis?.options.first)
    }
}
