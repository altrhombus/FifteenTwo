import Testing
import Foundation
import CribbageKit
@testable import CribbageBoardKit

/// `PhoneWatchSync`/`WatchPhoneSync` (in CribbageUI) send a `BoardMatch` across
/// WatchConnectivity as JSON — that plumbing itself isn't unit-testable without a real
/// paired device, but the round-trip encoding it depends on is, and is the part most
/// likely to silently break (e.g. a field that doesn't survive encoding).
struct BoardMatchCodableTests {
    @Test func boardMatchRoundTripsThroughJSON() throws {
        var match = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob", ruleset: .standard)
        match = BoardEngine.peg(match, playerIndex: 0, points: 8)
        match = BoardEngine.peg(match, playerIndex: 1, points: 5)

        let data = try JSONEncoder().encode(match)
        let decoded = try JSONDecoder().decode(BoardMatch.self, from: data)

        #expect(decoded == match)
        #expect(decoded.players[0].currentScore == 8)
        #expect(decoded.players[1].currentScore == 5)
    }

    @Test func completedMatchWithSkunkRoundTrips() throws {
        var match = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob", ruleset: Ruleset(gameTarget: 121))
        match = BoardEngine.peg(match, playerIndex: 1, points: 50)
        match = BoardEngine.peg(match, playerIndex: 0, points: 121)

        let data = try JSONEncoder().encode(match)
        let decoded = try JSONDecoder().decode(BoardMatch.self, from: data)

        #expect(decoded.isComplete)
        #expect(decoded.winnerIndex == 0)
        #expect(BoardEngine.skunkResult(for: decoded) == .doubleSkunk)
    }
}
