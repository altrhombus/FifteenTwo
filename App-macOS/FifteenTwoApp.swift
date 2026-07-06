import SwiftUI
import CribbageData

@main
struct FifteenTwoApp: App {
    // Falls back to an in-memory store if the persistent one fails to initialize —
    // history won't be saved, but the app stays launchable rather than crashing outright.
    private let modelContainer = (try? CribbageDataStack.makeModelContainer())
        ?? (try? CribbageDataStack.makeModelContainer(inMemory: true))
        ?? { fatalError("Could not create even an in-memory ModelContainer") }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
