#if os(watchOS)
import SwiftUI
import CribbageBoardKit

/// Drives the watch's board display: mirrors whatever the phone last sent, and sends peg
/// taps back up rather than holding any authoritative state of its own — see
/// `WatchPhoneSync`'s doc comment.
@Observable
@MainActor
final class WatchBoardController {
    private(set) var match: BoardMatch?
    private var sync: WatchPhoneSync?

    init() {
        sync = WatchPhoneSync { [weak self] match in
            self?.match = match
        }
    }

    func peg(playerIndex: Int, points: Int) {
        guard var updated = match, !updated.isComplete else { return }
        sync?.sendPeg(playerIndex: playerIndex, points: points)
        // Optimistic local update via the same shared BoardEngine — feels instant on the
        // wrist; the phone's next context push confirms (or corrects) it shortly after.
        updated = BoardEngine.peg(updated, playerIndex: playerIndex, points: points)
        match = updated
    }
}

/// The watch companion screen — "tap pegs from your wrist without pulling out the
/// phone," per docs/plan.md. A small set of the same common point values as the phone's
/// board screen, scaled down for the wrist.
public struct WatchBoardView: View {
    @State private var controller = WatchBoardController()
    private static let quickPoints = [1, 2, 3, 4, 6, 8, 12]

    public init() {}

    public var body: some View {
        Group {
            if let match = controller.match {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(match.players.indices, id: \.self) { index in
                            playerSection(for: match.players[index], index: index)
                        }
                        if match.isComplete {
                            Text("Game over").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for phone…").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func playerSection(for player: BoardPlayer, index: Int) -> some View {
        VStack(spacing: 4) {
            Text(player.name).font(.caption)
            Text("\(player.currentScore)").font(.title2.bold()).monospacedDigit()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 4) {
                ForEach(Self.quickPoints, id: \.self) { points in
                    Button("\(points)") {
                        controller.peg(playerIndex: index, points: points)
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.match?.isComplete ?? true)
                }
            }
        }
    }
}
#endif
