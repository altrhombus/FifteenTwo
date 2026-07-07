import SwiftData

/// Builds the shared `ModelContainer` — one place so every app target (iOS, macOS,
/// and the widget extension) gets an identical schema and storage configuration rather
/// than each hand-rolling its own.
///
/// `cloudKitEnabled` defaults to `false`: requesting CloudKit sync from SwiftData without
/// the app target actually having the iCloud/CloudKit capability and entitlement
/// configured throws at container creation, which would crash the app on launch. Flip it
/// to `true` once that capability is added in Xcode's Signing & Capabilities tab (a real,
/// mostly-automatic GUI step — not something safe to script blind) — see docs/plan.md
/// ("Cross-Device History Sync").
///
/// `useAppGroup` defaults to `false` for the same reason: requesting the
/// `group.com.altrhombus.FifteenTwo` container without the App Group entitlement present
/// would crash the same way. Pass `true` from any target that actually has the
/// entitlement (iOS and the widget extension, as of Post-MVP Widgets/Live Activities —
/// not yet macOS) so the widget can read the same board-match history the app writes.
public enum CribbageDataStack {
    static let appGroupIdentifier = "group.com.altrhombus.FifteenTwo"

    public static func makeModelContainer(
        cloudKitEnabled: Bool = false, useAppGroup: Bool = false, inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema([BoardMatchRecord.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            groupContainer: useAppGroup ? .identifier(appGroupIdentifier) : .none,
            cloudKitDatabase: cloudKitEnabled ? .automatic : .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
