import SwiftUI
import CribbageKit
import CribbageBoardKit
import CribbageSync
import CribbageVision
import CribbageData
import CribbageUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Fifteen Two")
                .font(.largeTitle.bold())
            Text("Scaffolding — not yet playable")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 480, minHeight: 320)
    }
}

#Preview {
    ContentView()
}
