import Foundation
import CribbageKit

/// Maps raw OCR text to a `Rank` — pure and framework-free so it's testable without Vision
/// or a camera, unlike the rest of this package. "10" is the one well-documented multi-
/// character misread Vision's text recognizer produces for card indices (split across two
/// glyphs, sometimes read as "1O"); everything else is an exact, case-insensitive match
/// rather than a guessed-at confusion table.
public enum RankTextMapper {
    private static let textToRank: [String: Rank] = [
        "A": .ace, "2": .two, "3": .three, "4": .four, "5": .five, "6": .six,
        "7": .seven, "8": .eight, "9": .nine, "10": .ten, "1O": .ten,
        "J": .jack, "Q": .queen, "K": .king
    ]

    public static func rank(from rawText: String) -> Rank? {
        textToRank[rawText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()]
    }
}
