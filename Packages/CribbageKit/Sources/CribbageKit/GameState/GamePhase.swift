public enum GamePhase: String, Codable, Equatable, Sendable {
    case dealing
    case discarding
    case cutStarter
    case pegging
    case counting
    case gameOver
}
