import SwiftUI
import CribbageData

@main
struct FifteenTwoApp: App {
    // CloudKit sync is off for now — see CribbageDataStack's doc comment: it requires
    // the iCloud/CloudKit capability to actually be added in Xcode's Signing &
    // Capabilities tab first, which isn't something safe to script blind.
    private let modelContainer = try! CribbageDataStack.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
