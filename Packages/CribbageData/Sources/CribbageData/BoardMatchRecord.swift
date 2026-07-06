import SwiftData
import Foundation
import CribbageKit
import CribbageBoardKit

/// The persisted form of a `BoardMatch` — see docs/plan.md ("Cross-Device History
/// Sync"). Fields are flat primitives with defaults (not a nested `Codable` blob)
/// deliberately: CloudKit-backed SwiftData models require every property to have a
/// default value or be optional, and no unique constraints — flat primitives make that
/// easy to satisfy and easy to reason about, at the cost of some conversion boilerplate
/// to and from `BoardMatch`.
@Model
public final class BoardMatchRecord {
    public var id: UUID = UUID()
    public var playerOneName: String = ""
    public var playerTwoName: String = ""
    public var playerOneScoreHistory: [Int] = []
    public var playerTwoScoreHistory: [Int] = []
    public var rulesetGameTarget: Int = 121
    public var rulesetSkunkThreshold: Int = 91
    public var rulesetDoubleSkunkThreshold: Int = 61
    public var rulesetMugginsEnabled: Bool = false
    public var rulesetExactThirtyOneScoresTwo: Bool = true
    public var startedAt: Date = Date()
    public var completedAt: Date?
    public var winnerIndex: Int?

    public init(match: BoardMatch) {
        id = match.id
        playerOneName = match.players[0].name
        playerTwoName = match.players[1].name
        playerOneScoreHistory = match.players[0].scoreHistory
        playerTwoScoreHistory = match.players[1].scoreHistory
        rulesetGameTarget = match.ruleset.gameTarget
        rulesetSkunkThreshold = match.ruleset.skunkThreshold
        rulesetDoubleSkunkThreshold = match.ruleset.doubleSkunkThreshold
        rulesetMugginsEnabled = match.ruleset.mugginsEnabled
        rulesetExactThirtyOneScoresTwo = match.ruleset.exactThirtyOneScoresTwo
        startedAt = match.startedAt
        completedAt = match.completedAt
        winnerIndex = match.winnerIndex
    }

    /// Overwrites every field from `match` — used to save an in-progress match's latest
    /// state over an existing record rather than creating a duplicate.
    public func update(from match: BoardMatch) {
        playerOneScoreHistory = match.players[0].scoreHistory
        playerTwoScoreHistory = match.players[1].scoreHistory
        completedAt = match.completedAt
        winnerIndex = match.winnerIndex
    }

    public var asBoardMatch: BoardMatch {
        var match = BoardMatch(
            playerOneName: playerOneName,
            playerTwoName: playerTwoName,
            ruleset: Ruleset(
                gameTarget: rulesetGameTarget,
                skunkThreshold: rulesetSkunkThreshold,
                doubleSkunkThreshold: rulesetDoubleSkunkThreshold,
                mugginsEnabled: rulesetMugginsEnabled,
                exactThirtyOneScoresTwo: rulesetExactThirtyOneScoresTwo
            )
        )
        match.id = id
        match.players[0].scoreHistory = playerOneScoreHistory
        match.players[1].scoreHistory = playerTwoScoreHistory
        match.startedAt = startedAt
        match.completedAt = completedAt
        match.winnerIndex = winnerIndex
        return match
    }
}
