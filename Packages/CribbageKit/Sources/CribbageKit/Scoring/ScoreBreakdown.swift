public struct ScoreBreakdown: Equatable, Codable, Sendable {
    public var fifteens: [ScoreEvent]
    public var pairs: [ScoreEvent]
    public var runs: [ScoreEvent]
    public var flush: [ScoreEvent]
    public var nobs: [ScoreEvent]

    public var allEvents: [ScoreEvent] { fifteens + pairs + runs + flush + nobs }

    public var total: Int { allEvents.reduce(0) { $0 + $1.points } }
}
