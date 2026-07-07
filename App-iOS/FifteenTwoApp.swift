import SwiftUI
import CribbageData
import CribbageUI

@main
struct FifteenTwoApp: App {
    // CloudKit sync is off for now — see CribbageDataStack's doc comment: it requires
    // the iCloud/CloudKit capability to actually be added in Xcode's Signing &
    // Capabilities tab first, which isn't something safe to script blind.
    //
    // App Group storage is on: the iOS target has the entitlement (see project.yml),
    // which is what lets FifteenTwoWidgets read the same board-match history this app
    // writes — see docs/plan.md's Post-MVP Widgets/Live Activities section.
    //
    // Falls back to an in-memory store if the persistent one fails to initialize —
    // history won't be saved, but the app stays launchable rather than crashing outright.
    private let modelContainer = (try? CribbageDataStack.makeModelContainer(useAppGroup: true))
        ?? (try? CribbageDataStack.makeModelContainer(inMemory: true))
        ?? { fatalError("Could not create even an in-memory ModelContainer") }()

    init() {
        GameCenterReporter.authenticateLocalPlayer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
