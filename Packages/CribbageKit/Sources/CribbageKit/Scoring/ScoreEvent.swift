public struct ScoreEvent: Equatable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case fifteen, pair, run, flush, nobs
    }

    public let kind: Kind
    public let cards: [Card]
    public let points: Int
}
