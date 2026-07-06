import Observation
import CribbageKit
import CribbageBoardKit
import CribbageData

/// Drives the physical-board companion mode — see docs/plan.md ("Physical board
/// companion mode"): a fast scorekeeper for people playing with a real board, with no
/// card/hand logic at all. Persists to `BoardHistoryStore` after every change so an
/// in-progress match survives the app being backgrounded or closed.
@Observable
@MainActor
public final class BoardSessionController {
    public private(set) var match: BoardMatch
    private let store: BoardHistoryStore

    public init(store: BoardHistoryStore, playerOneName: String = "Player 1", playerTwoName: String = "Player 2") {
        self.store = store
        self.match = BoardMatch(playerOneName: playerOneName, playerTwoName: playerTwoName)
        persist()
    }

    public var skunkResult: SkunkResult? { BoardEngine.skunkResult(for: match) }

    public func peg(playerIndex: Int, points: Int) {
        match = BoardEngine.peg(match, playerIndex: playerIndex, points: points)
        persist()
    }

    public func undoLastPeg(playerIndex: Int) {
        match = BoardEngine.undoLastPeg(match, playerIndex: playerIndex)
        persist()
    }

    public func startNewMatch(playerOneName: String, playerTwoName: String) {
        match = BoardMatch(playerOneName: playerOneName, playerTwoName: playerTwoName, ruleset: match.ruleset)
        persist()
    }

    public func fetchHistory() -> [BoardMatch] {
        (try? store.fetchAll()) ?? []
    }

    public func delete(_ historyMatch: BoardMatch) {
        try? store.delete(historyMatch)
    }

    private func persist() {
        try? store.save(match)
    }
}
