import Testing
import CribbageKit
@testable import CribbageBoardKit

struct BoardEngineTests {
    @Test func peggingAdvancesTheRightPlayersScore() {
        let match = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob")
        let afterFirst = BoardEngine.peg(match, playerIndex: 0, points: 8)

        #expect(afterFirst.players[0].currentScore == 8)
        #expect(afterFirst.players[0].previousScore == 0)
        #expect(afterFirst.players[1].currentScore == 0)

        let afterSecond = BoardEngine.peg(afterFirst, playerIndex: 0, points: 5)
        #expect(afterSecond.players[0].currentScore == 13)
        #expect(afterSecond.players[0].previousScore == 8) // the "back peg"
    }

    @Test func reachingTheTargetEndsTheMatch() {
        let match = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob", ruleset: Ruleset(gameTarget: 10))
        let finished = BoardEngine.peg(match, playerIndex: 1, points: 12)

        #expect(finished.isComplete)
        #expect(finished.winnerIndex == 1)
        #expect(finished.completedAt != nil)
    }

    @Test func undoLastPegReversesAScoreAndReopensAFinishedMatch() {
        let match = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob", ruleset: Ruleset(gameTarget: 10))
        let finished = BoardEngine.peg(match, playerIndex: 1, points: 12)
        #expect(finished.isComplete)

        let reopened = BoardEngine.undoLastPeg(finished, playerIndex: 1)
        #expect(!reopened.isComplete)
        #expect(reopened.winnerIndex == nil)
        #expect(reopened.players[1].currentScore == 0)
    }

    @Test func undoOnAnEmptyHistoryIsANoOp() {
        let match = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob")
        let unchanged = BoardEngine.undoLastPeg(match, playerIndex: 0)
        #expect(unchanged == match)
    }

    @Test func skunkResultReflectsTheLosersScoreAtGameEnd() {
        let ruleset = Ruleset(gameTarget: 121, skunkThreshold: 91, doubleSkunkThreshold: 61)
        var match = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob", ruleset: ruleset)
        match = BoardEngine.peg(match, playerIndex: 1, points: 55) // loser stays at 55
        match = BoardEngine.peg(match, playerIndex: 0, points: 121)

        #expect(BoardEngine.skunkResult(for: match) == .doubleSkunk) // 55 < 61

        var normalMatch = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob", ruleset: ruleset)
        normalMatch = BoardEngine.peg(normalMatch, playerIndex: 1, points: 100)
        normalMatch = BoardEngine.peg(normalMatch, playerIndex: 0, points: 121)
        #expect(BoardEngine.skunkResult(for: normalMatch) == .normal)
    }

    @Test func skunkResultIsNilForAnIncompleteMatch() {
        let match = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob")
        #expect(BoardEngine.skunkResult(for: match) == nil)
    }
}
