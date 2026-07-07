import ActivityKit
import WidgetKit
import SwiftUI
import CribbageBoardKit

struct BoardMatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BoardMatchActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.2))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    scoreColumn(name: context.attributes.playerOneName, score: context.state.playerOneScore)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    scoreColumn(name: context.attributes.playerTwoName, score: context.state.playerTwoScore)
                }
            } compactLeading: {
                Text("\(context.state.playerOneScore)")
            } compactTrailing: {
                Text("\(context.state.playerTwoScore)")
            } minimal: {
                Text("\(context.state.playerOneScore + context.state.playerTwoScore)")
            }
        }
    }

    private func scoreColumn(name: String, score: Int) -> some View {
        VStack {
            Text(name).font(.caption)
            Text("\(score)").font(.title2.bold())
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<BoardMatchActivityAttributes>

    var body: some View {
        VStack(spacing: 6) {
            Text("\(context.attributes.playerOneName) vs \(context.attributes.playerTwoName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                scoreColumn(name: context.attributes.playerOneName, score: context.state.playerOneScore)
                Spacer()
                scoreColumn(name: context.attributes.playerTwoName, score: context.state.playerTwoScore)
            }
            if context.state.isComplete, let winnerIndex = context.state.winnerIndex {
                Text(winnerName(winnerIndex) + " wins!")
                    .font(.subheadline.bold())
            }
        }
        .padding()
    }

    private func winnerName(_ index: Int) -> String {
        index == 0 ? context.attributes.playerOneName : context.attributes.playerTwoName
    }

    private func scoreColumn(name: String, score: Int) -> some View {
        VStack {
            Text(name).font(.caption)
            Text("\(score)").font(.title.bold())
        }
    }
}
