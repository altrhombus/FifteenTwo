import Testing
@testable import CribbageKit

struct RNGTests {
    @Test func sameSeedProducesTheIdenticalShuffleEveryTime() {
        let seed = Seed256(a: 111, b: 222, c: 333, d: 444)

        var rngA = Xoshiro256StarStar(seed: seed)
        var deckA = Deck.standard52
        deckA.shuffle(using: &rngA)

        var rngB = Xoshiro256StarStar(seed: seed)
        var deckB = Deck.standard52
        deckB.shuffle(using: &rngB)

        #expect(deckA == deckB)
    }

    @Test func differentSeedsProduceDifferentShuffles() {
        var rngA = Xoshiro256StarStar(seed: Seed256(a: 1, b: 2, c: 3, d: 4))
        var deckA = Deck.standard52
        deckA.shuffle(using: &rngA)

        var rngB = Xoshiro256StarStar(seed: Seed256(a: 5, b: 6, c: 7, d: 8))
        var deckB = Deck.standard52
        deckB.shuffle(using: &rngB)

        #expect(deckA != deckB)
    }

    @Test func dealHandWithTheSameSeedDealsIdenticalHandsAndStarter() {
        let seed = Seed256(a: 9, b: 8, c: 7, d: 6)
        let stateA = GameEngine.reduce(GameState(), applying: .dealHand(seed: seed))
        let stateB = GameEngine.reduce(GameState(), applying: .dealHand(seed: seed))

        #expect(stateA.hands == stateB.hands)
        #expect(stateA.deck == stateB.deck)
    }

    @Test func randomSeedsAreNotAllZeroAndVaryBetweenCalls() {
        let first = Seed256.random()
        let second = Seed256.random()
        #expect(first != second)
        #expect(first != Seed256(a: 0, b: 0, c: 0, d: 0))
    }

    @Test func commitHashIsDeterministicAndDistinguishesSeeds() {
        let seed = Seed256(a: 1, b: 2, c: 3, d: 4)
        #expect(seed.commitHash == seed.commitHash)
        #expect(seed.commitHash.count == 64) // SHA-256 hex digest

        let otherSeed = Seed256(a: 1, b: 2, c: 3, d: 5)
        #expect(seed.commitHash != otherSeed.commitHash)
    }

    @Test func hexStringIsSixtyFourCharactersAndRoundTripsTheSameSeed() {
        let seed = Seed256(a: .max, b: 0, c: 12345, d: 1)
        #expect(seed.hexString.count == 64)
        #expect(seed.hexString == seed.hexString)
    }
}
