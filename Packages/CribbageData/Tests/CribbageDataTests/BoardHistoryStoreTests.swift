import Testing
import SwiftData
import CribbageKit
import CribbageBoardKit
@testable import CribbageData

@MainActor
struct BoardHistoryStoreTests {
    private func makeStore() throws -> BoardHistoryStore {
        let container = try CribbageDataStack.makeModelContainer(inMemory: true)
        return BoardHistoryStore(modelContext: ModelContext(container))
    }

    @Test func savingAndFetchingRoundTripsAMatch() throws {
        let store = try makeStore()
        var match = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob")
        match = BoardEngine.peg(match, playerIndex: 0, points: 8)

        try store.save(match)
        let fetched = try store.fetchAll()

        #expect(fetched.count == 1)
        #expect(fetched[0].id == match.id)
        #expect(fetched[0].players[0].name == "Alice")
        #expect(fetched[0].players[0].currentScore == 8)
    }

    @Test func savingTheSameMatchAgainUpdatesRatherThanDuplicates() throws {
        let store = try makeStore()
        var match = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob")
        try store.save(match)

        match = BoardEngine.peg(match, playerIndex: 0, points: 6)
        try store.save(match)

        let fetched = try store.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched[0].players[0].currentScore == 6)
    }

    @Test func fetchAllOrdersByMostRecentlyStartedFirst() throws {
        let store = try makeStore()
        let older = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob")
        try store.save(older)

        var newer = BoardMatch(playerOneName: "Carol", playerTwoName: "Dave")
        newer.startedAt = older.startedAt.addingTimeInterval(60)
        try store.save(newer)

        let fetched = try store.fetchAll()
        #expect(fetched.count == 2)
        #expect(fetched[0].id == newer.id)
        #expect(fetched[1].id == older.id)
    }

    @Test func deleteRemovesOnlyTheTargetedMatch() throws {
        let store = try makeStore()
        let match1 = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob")
        let match2 = BoardMatch(playerOneName: "Carol", playerTwoName: "Dave")
        try store.save(match1)
        try store.save(match2)

        try store.delete(match1)

        let fetched = try store.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched[0].id == match2.id)
    }

    @Test func rulesetRoundTripsThroughPersistence() throws {
        let store = try makeStore()
        let ruleset = Ruleset(
            gameTarget: 61, skunkThreshold: 45, doubleSkunkThreshold: 30,
            mugginsEnabled: true, exactThirtyOneScoresTwo: false
        )
        let match = BoardMatch(playerOneName: "Alice", playerTwoName: "Bob", ruleset: ruleset)
        try store.save(match)

        let fetched = try store.fetchAll()[0]
        #expect(fetched.ruleset == ruleset)
    }
}
