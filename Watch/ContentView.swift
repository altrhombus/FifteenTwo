import SwiftUI
import CribbageKit
import CribbageBoardKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Fifteen Two")
                .font(.headline)
            Text("Scaffolding")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
