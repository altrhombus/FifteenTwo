import SwiftData

/// Builds the shared `ModelContainer` — one place so every app target (iOS today,
/// macOS/watchOS in Phase 9) gets an identical schema and CloudKit configuration rather
/// than each hand-rolling its own.
///
/// `cloudKitEnabled` defaults to `false`: requesting CloudKit sync from SwiftData without
/// the app target actually having the iCloud/CloudKit capability and entitlement
/// configured throws at container creation, which would crash the app on launch. Flip it
/// to `true` once that capability is added in Xcode's Signing & Capabilities tab (a real,
/// mostly-automatic GUI step — not something safe to script blind) — see docs/plan.md
/// ("Cross-Device History Sync").
public enum CribbageDataStack {
    public static func makeModelContainer(
        cloudKitEnabled: Bool = false, inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema([BoardMatchRecord.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKitEnabled ? .automatic : .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
