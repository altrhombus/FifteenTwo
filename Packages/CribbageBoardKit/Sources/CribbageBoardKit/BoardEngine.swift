import CribbageKit
import Foundation

/// Pure operations on a `BoardMatch` — tap a peg forward, undo a mis-tap, and detect
/// skunks on completion. Reuses `SkunkResult` from `CribbageKit` (already the right type
/// for this — no need for a second one).
public enum BoardEngine {
    /// Advances `playerIndex`'s score by `points`. Auto-detects game-over the moment
    /// either player reaches the ruleset's target, matching how a real board game ends
    /// the instant someone pegs out.
    public static func peg(_ match: BoardMatch, playerIndex: Int, points: Int) -> BoardMatch {
        precondition(match.players.indices.contains(playerIndex), "No player at index \(playerIndex)")
        precondition(points > 0, "Must peg a positive number of points")
        precondition(!match.isComplete, "Cannot peg in a completed match")

        var next = match
        let newScore = next.players[playerIndex].currentScore + points
        next.players[playerIndex].scoreHistory.append(newScore)

        if newScore >= next.ruleset.gameTarget {
            next.completedAt = Date()
            next.winnerIndex = playerIndex
        }
        return next
    }

    /// Undoes the most recent peg for `playerIndex` — mis-taps happen. If that peg was
    /// what ended the match, this reopens it.
    public static func undoLastPeg(_ match: BoardMatch, playerIndex: Int) -> BoardMatch {
        precondition(match.players.indices.contains(playerIndex), "No player at index \(playerIndex)")

        var next = match
        guard !next.players[playerIndex].scoreHistory.isEmpty else { return next }
        next.players[playerIndex].scoreHistory.removeLast()

        if next.winnerIndex == playerIndex, next.players[playerIndex].currentScore < next.ruleset.gameTarget {
            next.completedAt = nil
            next.winnerIndex = nil
        }
        return next
    }

    public static func skunkResult(for match: BoardMatch) -> SkunkResult? {
        guard match.isComplete, let winnerIndex = match.winnerIndex else { return nil }
        let loserIndex = winnerIndex == 0 ? 1 : 0
        let loserScore = match.players[loserIndex].currentScore
        if loserScore < match.ruleset.doubleSkunkThreshold { return .doubleSkunk }
        if loserScore < match.ruleset.skunkThreshold { return .skunk }
        return .normal
    }
}
