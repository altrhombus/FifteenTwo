import SwiftUI
import CribbageUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Play", systemImage: "suit.spade.fill") {
                GameView()
            }
            Tab("Board", systemImage: "number") {
                BoardView()
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
