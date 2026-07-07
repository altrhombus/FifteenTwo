import SwiftUI
import CribbageUI

struct ContentView: View {
    @State private var settings = SettingsStore()

    var body: some View {
        TabView {
            Tab("Play", systemImage: "suit.spade.fill") {
                GameView(settings: settings)
            }
            Tab("Board", systemImage: "number") {
                BoardView()
            }
            Tab("Multiplayer", systemImage: "person.2.fill") {
                MultiplayerGameView()
            }
            Tab("Scan", systemImage: "camera.viewfinder") {
                ScanView()
            }
            Tab("Turn-Based", systemImage: "hourglass") {
                TurnBasedGamesView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView(settings: settings)
            }
        }
        // On iPad's regular width class this renders as a sidebar instead of a bottom
        // tab bar (docs/plan.md Phase 9: "adaptive layouts") — free on iPhone too, since
        // it's still a plain tab bar in compact width there.
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    ContentView()
}
