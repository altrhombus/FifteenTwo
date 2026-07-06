public struct ScoreEvent: Equatable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        // Hand/crib scoring (`Scorer`)
        case fifteen, pair, run, flush, nobs
        // Pegging-only events (`GameEngine`)
        case thirtyOne, go, hisHeels
    }

    public let kind: Kind
    public let cards: [Card]
    public let points: Int
}
