#if os(iOS)
import ActivityKit
import Foundation

/// Live Activity state for an in-progress physical board match — see docs/plan.md's
/// Post-MVP "Widgets/Live Activities" item. Lives in `CribbageBoardKit` (not `CribbageUI`
/// or the widget extension) so both `FifteenTwo-iOS` (which starts/updates/ends the
/// activity) and `FifteenTwoWidgets` (which renders it) can import the same type without
/// depending on each other.
///
/// ActivityKit is iOS-only (unavailable on macOS/watchOS), unlike the rest of this
/// otherwise-cross-platform package.
public struct BoardMatchActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var playerOneScore: Int
        public var playerTwoScore: Int
        public var isComplete: Bool
        public var winnerIndex: Int?

        public init(playerOneScore: Int, playerTwoScore: Int, isComplete: Bool, winnerIndex: Int?) {
            self.playerOneScore = playerOneScore
            self.playerTwoScore = playerTwoScore
            self.isComplete = isComplete
            self.winnerIndex = winnerIndex
        }
    }

    public var playerOneName: String
    public var playerTwoName: String
    public var matchID: UUID

    public init(playerOneName: String, playerTwoName: String, matchID: UUID) {
        self.playerOneName = playerOneName
        self.playerTwoName = playerTwoName
        self.matchID = matchID
    }
}

public extension BoardMatchActivityAttributes.ContentState {
    init(match: BoardMatch) {
        self.init(
            playerOneScore: match.players[0].currentScore,
            playerTwoScore: match.players[1].currentScore,
            isComplete: match.isComplete,
            winnerIndex: match.winnerIndex
        )
    }
}
#endif
