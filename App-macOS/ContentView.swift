import SwiftUI
import CribbageUI

/// Mac's idiom for a two-section app is a sidebar, not a tab bar (see docs/plan.md
/// Phase 9: "adaptive layouts... Mac windowing/pointer support") — `GameView`/`BoardView`
/// are reused unchanged from CribbageUI, each keeping its own internal `NavigationStack`
/// as the detail column's content.
private enum Section: String, CaseIterable, Identifiable {
    case play = "Play"
    case board = "Board"
    case multiplayer = "Multiplayer"
    case scan = "Scan"
    case settings = "Settings"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .play: "suit.spade.fill"
        case .board: "number"
        case .multiplayer: "person.2.fill"
        case .scan: "camera.viewfinder"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selection: Section? = .play
    @State private var settings = SettingsStore()

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(180)
        } detail: {
            switch selection {
            case .play, .none:
                GameView(settings: settings)
            case .board:
                BoardView()
            case .multiplayer:
                MultiplayerGameView()
            case .scan:
                ScanView()
            case .settings:
                SettingsView(settings: settings)
            }
        }
        .frame(minWidth: 900, minHeight: 640)
    }
}

#Preview {
    ContentView()
}
