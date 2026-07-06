#if !os(watchOS)
import SwiftUI
import CribbageKit
import CribbageSync
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

private enum ConnectionStatus: Equatable {
    case notConnected
    case hostingMultipeer
    case browsingMultipeer
    case waitingForSharePlay
    case connected
}

/// Local pass-and-play — see docs/plan.md ("Multipeer pass-and-play", "SharePlay"): both
/// transports share the same `MultiplayerSessionController`/`GameEngine.reduce` game
/// logic, so this view's only real job is the connection UX, which genuinely differs per
/// transport (a host/join lobby for Multipeer vs. offering the activity during a FaceTime
/// call for SharePlay). Neither transport works in Simulator (both need real hardware —
/// SharePlay specifically needs an active FaceTime call between two different Apple IDs),
/// so this is built to be exercised solo up through the lobby/connection screen and
/// verified end to end on real devices.
public struct MultiplayerGameView: View {
    @State private var multipeerTransport: MultipeerGameTransport?
    @State private var groupTransport: GroupActivityGameTransport?
    @State private var controller: MultiplayerSessionController?
    @State private var connectionStatus: ConnectionStatus = .notConnected
    @State private var showingBrowser = false
    @State private var displayName = defaultDisplayName()

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if let controller, connectionStatus == .connected {
                    MultiplayerPlayView(controller: controller, onDisconnect: cancelConnecting)
                } else if connectionStatus == .notConnected {
                    LobbyView(
                        displayName: $displayName,
                        onHostMultipeer: hostMultipeer,
                        onJoinMultipeer: joinMultipeer,
                        onStartSharePlay: startSharePlay
                    )
                } else {
                    WaitingToConnectView(status: connectionStatus, onCancel: cancelConnecting)
                }
            }
            .navigationTitle("Pass and Play")
        }
        .sheet(isPresented: $showingBrowser) {
            if let multipeerTransport {
                PeerBrowserView(browser: multipeerTransport.browser, session: multipeerTransport.session) {
                    showingBrowser = false
                }
            }
        }
    }

    private func hostMultipeer() {
        let transport = MultipeerGameTransport(displayName: displayName)
        multipeerTransport = transport
        connectionStatus = .hostingMultipeer
        transport.onConnectedPeersChanged = { [weak transport] peerNames in
            guard let transport, !peerNames.isEmpty else { return }
            controller = MultiplayerSessionController(transport: transport, mySeat: .playerOne)
            connectionStatus = .connected
        }
        transport.startHosting()
    }

    private func joinMultipeer() {
        let transport = MultipeerGameTransport(displayName: displayName)
        multipeerTransport = transport
        connectionStatus = .browsingMultipeer
        transport.onConnectedPeersChanged = { [weak transport] peerNames in
            guard let transport, !peerNames.isEmpty else { return }
            controller = MultiplayerSessionController(transport: transport, mySeat: .playerTwo)
            connectionStatus = .connected
        }
        showingBrowser = true
    }

    private func startSharePlay() {
        let transport = GroupActivityGameTransport()
        groupTransport = transport
        connectionStatus = .waitingForSharePlay
        transport.observeSessions()
        transport.onParticipantsChanged = { [weak transport] count in
            guard let transport, count >= 2, let seat = transport.mySeat else { return }
            controller = MultiplayerSessionController(transport: transport, mySeat: seat)
            connectionStatus = .connected
        }
        Task { await transport.activate() }
    }

    private func cancelConnecting() {
        multipeerTransport?.disconnect()
        groupTransport?.leave()
        multipeerTransport = nil
        groupTransport = nil
        controller = nil
        connectionStatus = .notConnected
    }
}

private struct LobbyView: View {
    @Binding var displayName: String
    let onHostMultipeer: () -> Void
    let onJoinMultipeer: () -> Void
    let onStartSharePlay: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Play a real hand with someone else, either in the same room or together on FaceTime.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Your name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)

            Button("Host a Game Nearby", systemImage: "antenna.radiowaves.left.and.right", action: onHostMultipeer)
                .buttonStyle(.borderedProminent)
            Button("Join a Game Nearby", systemImage: "magnifyingglass", action: onJoinMultipeer)
                .buttonStyle(.bordered)

            Divider().frame(maxWidth: 280)

            Button("Play over SharePlay", systemImage: "shareplay", action: onStartSharePlay)
                .buttonStyle(.bordered)
            Text("Requires an active FaceTime call with the other player.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct WaitingToConnectView: View {
    let status: ConnectionStatus
    let onCancel: () -> Void

    private var message: String {
        switch status {
        case .hostingMultipeer: "Waiting for someone to join…"
        case .browsingMultipeer: "Looking for a nearby game…"
        case .waitingForSharePlay: "Waiting for the other player to join over SharePlay…"
        case .notConnected, .connected: ""
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(message).font(.headline)
            Button("Cancel", role: .cancel, action: onCancel)
        }
        .padding()
    }
}

private struct MultiplayerPlayView: View {
    let controller: MultiplayerSessionController
    let onDisconnect: () -> Void

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
                MultiplayerGameOverView(controller: controller, onDisconnect: onDisconnect)
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

#Preview {
    MultiplayerGameView()
}
#endif
