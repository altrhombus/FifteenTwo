import Testing
import CribbageKit
@testable import CribbageVision

/// Pure and framework-free, unlike the rest of this package — no Vision/camera needed to
/// test the actual OCR-text-to-Rank logic exhaustively.
struct RankTextMapperTests {
    @Test(arguments: [
        ("A", Rank.ace), ("2", .two), ("3", .three), ("4", .four), ("5", .five),
        ("6", .six), ("7", .seven), ("8", .eight), ("9", .nine),
        ("10", .ten), ("1O", .ten),
        ("J", .jack), ("Q", .queen), ("K", .king)
    ])
    func mapsKnownOCRTextToTheCorrectRank(text: String, expected: Rank) {
        #expect(RankTextMapper.rank(from: text) == expected)
    }

    @Test func lowercaseInputStillMaps() {
        #expect(RankTextMapper.rank(from: "a") == .ace)
        #expect(RankTextMapper.rank(from: "k") == .king)
    }

    @Test func whitespaceIsTrimmedBeforeMatching() {
        #expect(RankTextMapper.rank(from: " 7 \n") == .seven)
    }

    @Test func unrecognizedTextReturnsNil() {
        #expect(RankTextMapper.rank(from: "") == nil)
        #expect(RankTextMapper.rank(from: "?!") == nil)
        #expect(RankTextMapper.rank(from: "XYZ") == nil)
    }
}
