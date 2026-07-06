import Observation
import CribbageKit
import CribbageBoardKit
import CribbageData

/// Drives the physical-board companion mode — see docs/plan.md ("Physical board
/// companion mode"): a fast scorekeeper for people playing with a real board, with no
/// card/hand logic at all. Persists to `BoardHistoryStore` after every change so an
/// in-progress match survives the app being backgrounded or closed.
///
/// On iOS, also pushes every change to a paired watch (see `PhoneWatchSync`) and applies
/// "peg" requests the watch sends back — the phone stays the single source of truth per
/// docs/plan.md ("watchOS Companion").
@Observable
@MainActor
public final class BoardSessionController {
    public private(set) var match: BoardMatch
    private let store: BoardHistoryStore
    #if os(iOS)
    private var watchSync: PhoneWatchSync?
    #endif

    public init(store: BoardHistoryStore, playerOneName: String = "Player 1", playerTwoName: String = "Player 2") {
        self.store = store
        self.match = BoardMatch(playerOneName: playerOneName, playerTwoName: playerTwoName)
        persist()
        #if os(iOS)
        watchSync = PhoneWatchSync { [weak self] playerIndex, points in
            self?.peg(playerIndex: playerIndex, points: points)
        }
        watchSync?.send(match)
        #endif
    }

    public var skunkResult: SkunkResult? { BoardEngine.skunkResult(for: match) }

    public func peg(playerIndex: Int, points: Int) {
        guard !match.isComplete else { return }
        match = BoardEngine.peg(match, playerIndex: playerIndex, points: points)
        #if !os(watchOS)
        if match.isComplete {
            GameCenterReporter.reportBoardMatchCompleted(match)
        }
        #endif
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
        #if os(iOS)
        watchSync?.send(match)
        #endif
    }
}
