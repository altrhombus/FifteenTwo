/// Red vs. black — the one suit-adjacent property this project auto-detects. See the
/// package doc comment on `CardScanner` for why full 4-suit detection stays manual.
public enum CardColor: String, Codable, Sendable, Equatable {
    case red, black
}
