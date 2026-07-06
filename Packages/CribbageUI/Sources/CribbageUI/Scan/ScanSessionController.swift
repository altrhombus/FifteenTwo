#if os(iOS) || os(macOS)
import Foundation
import Observation
import CoreGraphics
import CribbageKit
import CribbageVision

/// One card as shown on the confirmation screen — pre-filled from `CardScanner`'s guess,
/// always editable, never trusted until the person confirms it. See docs/plan.md: "a
/// misread feeding 'optimal' advice is worse than no advice."
public struct EditableCardGuess: Identifiable, Sendable {
    public let id: UUID
    public var rank: Rank?
    public var suit: Suit?
    public var suggestedColor: CardColor?
    public var cornerImage: CGImage?

    public var resolvedCard: Card? {
        guard let rank, let suit else { return nil }
        return Card(rank: rank, suit: suit)
    }
}

/// Drives the "scan your real hand" coach feature — see docs/plan.md ("Vision Hand-
/// Scanning"): photo in, editable per-card guesses out, `DiscardSolver` analysis once all
/// 6 are confirmed. `CardScanner` does the actual detection/OCR/color work; this just
/// holds the resulting guesses as UI state and turns them into `Card`s once a person has
/// confirmed each one.
@Observable
@MainActor
public final class ScanSessionController {
    public private(set) var guesses: [EditableCardGuess] = []
    public private(set) var isScanning = false
    public private(set) var scanErrorMessage: String?
    public var isDealer = false
    public private(set) var analysis: [DiscardOption] = []

    public init() {}

    public func scan(_ cgImage: CGImage) {
        isScanning = true
        scanErrorMessage = nil
        analysis = []
        Task {
            do {
                let scanned = try await Task.detached(priority: .userInitiated) {
                    try CardScanner.scan(cgImage)
                }.value
                guesses = scanned.map {
                    EditableCardGuess(
                        id: $0.id, rank: $0.guessedRank, suit: nil,
                        suggestedColor: $0.guessedColor, cornerImage: $0.cornerImage
                    )
                }
                if guesses.isEmpty {
                    scanErrorMessage =
                        "Couldn't find any cards in that photo. Try again with better lighting and the cards laid flat."
                }
            } catch {
                scanErrorMessage = "Scanning failed: \(error.localizedDescription)"
            }
            isScanning = false
        }
    }

    public func addBlankGuess() {
        guesses.append(EditableCardGuess(id: UUID(), rank: nil, suit: nil, suggestedColor: nil, cornerImage: nil))
    }

    public func removeGuess(id: UUID) {
        guesses.removeAll { $0.id == id }
    }

    public func updateGuess(id: UUID, rank: Rank?, suit: Suit?) {
        guard let index = guesses.firstIndex(where: { $0.id == id }) else { return }
        guesses[index].rank = rank
        guesses[index].suit = suit
    }

    /// All 6 cards confirmed with no rank/suit left blank and no duplicates — the same
    /// precondition `GameEngine`/`DiscardSolver` assume of a real dealt hand.
    public var resolvedHand: [Card]? {
        guard guesses.count == 6 else { return nil }
        let cards = guesses.compactMap(\.resolvedCard)
        guard cards.count == 6, Set(cards).count == 6 else { return nil }
        return cards
    }

    public func analyzeDiscard() {
        guard let hand = resolvedHand else { return }
        analysis = DiscardSolver.bestDiscards(hand: hand, isDealer: isDealer)
    }

    public func reset() {
        guesses = []
        analysis = []
        scanErrorMessage = nil
    }
}
#endif
