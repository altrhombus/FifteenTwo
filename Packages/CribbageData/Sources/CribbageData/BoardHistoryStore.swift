import SwiftData
import Foundation
import CribbageBoardKit

/// Save/fetch/delete for `BoardMatch` history, wrapping a `ModelContext` so the UI layer
/// doesn't need to know about `BoardMatchRecord` or fetch descriptors at all.
@MainActor
public final class BoardHistoryStore {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Inserts a new record, or updates the existing one for `match.id` if it's already
    /// been saved — an in-progress match is saved repeatedly as it's played, not just once
    /// at the end.
    public func save(_ match: BoardMatch) throws {
        let id = match.id
        let descriptor = FetchDescriptor<BoardMatchRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.update(from: match)
        } else {
            modelContext.insert(BoardMatchRecord(match: match))
        }
        try modelContext.save()
    }

    public func fetchAll() throws -> [BoardMatch] {
        let descriptor = FetchDescriptor<BoardMatchRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.asBoardMatch)
    }

    public func delete(_ match: BoardMatch) throws {
        let id = match.id
        let descriptor = FetchDescriptor<BoardMatchRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try modelContext.save()
        }
    }
}
