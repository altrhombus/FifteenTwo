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
    }
}

#Preview {
    ContentView()
}
