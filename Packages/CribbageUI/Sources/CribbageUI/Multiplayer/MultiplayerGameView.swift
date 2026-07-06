#if !os(watchOS)
import SwiftUI
import CribbageKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private func defaultDisplayName() -> String {
    #if os(iOS)
    UIDevice.current.name
    #elseif os(macOS)
    Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    #else
    ProcessInfo.processInfo.hostName
    #endif
}

/// Local pass-and-play over Multipeer — see docs/plan.md ("Multipeer pass-and-play").
/// Multipeer itself doesn't work in Simulator (needs real hardware on both ends), so this
/// view is built to be exercised solo up through the lobby/connection screen and verified
/// end to end on real devices.
public struct MultiplayerGameView: View {
    @State private var controller: MultiplayerSessionController?
    @State private var showingBrowser = false
    @State private var displayName = defaultDisplayName()

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if let controller {
                    connectedContent(controller)
                } else {
                    LobbyView(displayName: $displayName, onHost: host, onJoin: join)
                }
            }
            .navigationTitle("Pass and Play")
        }
        .sheet(isPresented: $showingBrowser) {
            if let controller {
                PeerBrowserView(browser: controller.browser, session: controller.session) {
                    showingBrowser = false
                }
            }
        }
    }

    @ViewBuilder
    private func connectedContent(_ controller: MultiplayerSessionController) -> some View {
        switch controller.connectionState {
        case .notConnected, .hosting, .browsing:
            WaitingToConnectView(controller: controller)
        case .connected:
            MultiplayerPlayView(controller: controller)
        }
    }

    private func host() {
        let controller = MultiplayerSessionController(displayName: displayName, mySeat: .playerOne)
        self.controller = controller
        controller.startHosting()
    }

    private func join() {
        let controller = MultiplayerSessionController(displayName: displayName, mySeat: .playerTwo)
        self.controller = controller
        controller.startBrowsing()
        showingBrowser = true
    }
}

private struct LobbyView: View {
    @Binding var displayName: String
    let onHost: () -> Void
    let onJoin: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Play a real hand with someone else in the room, passing the device back and forth for pegging.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Your name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)

            Button("Host a Game", systemImage: "antenna.radiowaves.left.and.right", action: onHost)
                .buttonStyle(.borderedProminent)
            Button("Join a Game", systemImage: "magnifyingglass", action: onJoin)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

private struct WaitingToConnectView: View {
    let controller: MultiplayerSessionController

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(controller.connectionState == .hosting
                ? "Waiting for someone to join…"
                : "Looking for a nearby game…")
                .font(.headline)
            Button("Cancel", role: .cancel) {
                controller.disconnect()
            }
        }
        .padding()
    }
}

private struct MultiplayerPlayView: View {
    let controller: MultiplayerSessionController

    var body: some View {
        VStack(spacing: 16) {
            MultiplayerScoreHeader(controller: controller)
            Divider()

            switch controller.state.phase {
            case .dealing:
                ProgressView()
            case .discarding:
                MultiplayerDiscardingView(controller: controller)
            case .cutStarter:
                MultiplayerCutStarterView(controller: controller)
            case .pegging:
                MultiplayerPeggingView(controller: controller)
            case .counting:
                MultiplayerCountingView(controller: controller)
            case .gameOver:
                MultiplayerGameOverView(controller: controller)
            }

            Spacer()
        }
        .padding()
        .task {
            if controller.state.phase == .dealing {
                controller.dealIfMyTurn()
            }
        }
    }
}

private struct MultiplayerScoreHeader: View {
    let controller: MultiplayerSessionController

    var body: some View {
        HStack {
            scoreColumn(
                title: "You",
                score: controller.state.scores[controller.mySeat],
                isDealer: controller.state.dealer == controller.mySeat
            )
            Spacer()
            scoreColumn(
                title: "Opponent",
                score: controller.state.scores[controller.opponentSeat],
                isDealer: controller.state.dealer == controller.opponentSeat
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func scoreColumn(title: String, score: Int, isDealer: Bool) -> some View {
        VStack {
            Text(title).font(.headline)
            Text("\(score)").font(.largeTitle.monospacedDigit())
            if isDealer {
                Text("Dealer").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MultiplayerDiscardingView: View {
    let controller: MultiplayerSessionController
    @State private var selected: [Card] = []
    @State private var hasDiscarded = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose 2 cards to discard to the crib")
                .font(.headline)
            if hasDiscarded {
                Text("Waiting for your opponent to discard…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(controller.state.hands[controller.mySeat]) { card in
                    Button {
                        toggle(card)
                    } label: {
                        CardLabel(
                            card: card,
                            isSelected: selected.contains(card),
                            accessibilityState: selected.contains(card) ? "selected for discard" : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(hasDiscarded)
                }
            }
            Button("Discard") {
                controller.discard(selected)
                hasDiscarded = true
            }
            .disabled(selected.count != 2 || hasDiscarded)
            .buttonStyle(.borderedProminent)
        }
    }

    private func toggle(_ card: Card) {
        if let index = selected.firstIndex(of: card) {
            selected.remove(at: index)
            return
        }
        selected.append(card)
        if selected.count > 2 {
            selected.removeFirst()
        }
    }
}

private struct MultiplayerCutStarterView: View {
    let controller: MultiplayerSessionController

    private var isMyCut: Bool { controller.state.dealer.opponent == controller.mySeat }

    var body: some View {
        VStack(spacing: 16) {
            Text("Both hands are set.")
                .font(.headline)
            if isMyCut {
                Button("Cut for Starter") {
                    controller.cutForStarterIfMyTurn()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Waiting for your opponent to cut the deck…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MultiplayerPeggingView: View {
    let controller: MultiplayerSessionController

    private var isMyTurn: Bool { controller.state.turnToAct == controller.mySeat }

    var body: some View {
        VStack(spacing: 16) {
            if let starter = controller.state.starter {
                Label("Starter: \(starter.rank.symbol)\(starter.suit.symbol)", systemImage: "star.fill")
                    .font(.subheadline)
                    .accessibilityLabel("Starter: \(starter.spokenName)")
            }

            Text("Count: \(controller.state.peggingCount)")
                .font(.title2.monospacedDigit())

            HStack(spacing: 8) {
                ForEach(controller.state.peggingPile) { card in
                    CardLabel(card: card)
                }
            }
            .frame(minHeight: 60)

            Text("Opponent has \(controller.state.peggingRemaining[controller.opponentSeat].count) card(s) left")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text(isMyTurn ? "Your turn" : "Waiting for opponent…")
                .font(.headline)

            let legalPlays = controller.legalMyPlays
            HStack(spacing: 8) {
                ForEach(controller.state.peggingRemaining[controller.mySeat]) { card in
                    Button {
                        controller.play(card)
                    } label: {
                        CardLabel(
                            card: card,
                            accessibilityState: legalPlays.contains(card) ? "playable" : "not currently playable"
                        )
                        .opacity(legalPlays.contains(card) ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isMyTurn || !legalPlays.contains(card))
                }
            }

            if isMyTurn && legalPlays.isEmpty {
                Text("No card you hold fits under 31 — say Go to pass.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Go") {
                    controller.sayGo()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct MultiplayerCountingView: View {
    let controller: MultiplayerSessionController

    private var isMyDeal: Bool { controller.state.dealer == controller.mySeat }

    var body: some View {
        if let summary = controller.state.lastRoundSummary {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hand Summary").font(.headline)
                Text("Non-dealer's hand: \(summary.nonDealerHand.total) pts")
                if let dealerHand = summary.dealerHand {
                    Text("Dealer's hand: \(dealerHand.total) pts")
                }
                if let crib = summary.crib {
                    Text("Crib: \(crib.total) pts")
                }

                Divider()
                if isMyDeal {
                    Button("Deal Next Hand") {
                        controller.dealIfMyTurn()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Waiting for your opponent to deal…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct MultiplayerGameOverView: View {
    let controller: MultiplayerSessionController

    var body: some View {
        VStack(spacing: 16) {
            let youWon = controller.state.winner == controller.mySeat
            Text(youWon ? "You win!" : "Your opponent wins")
                .font(.largeTitle.bold())
            if let skunk = controller.state.skunkResult, skunk != .normal {
                Text(skunk == .doubleSkunk ? "Double skunk!" : "Skunk!")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
            Button("Disconnect") {
                controller.disconnect()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    MultiplayerGameView()
}
#endif
