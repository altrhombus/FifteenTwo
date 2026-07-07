#if os(iOS)
import SwiftUI
import UIKit
import GameKit

/// Wraps the system's own turn-based matchmaking UI (invite friends, auto-match, browse
/// existing matches) — same rationale as `PeerBrowserView` for Multipeer: finding/inviting
/// an opponent is the part worth a system-provided UI, not something to build by hand.
struct TurnBasedMatchmakerView: UIViewControllerRepresentable {
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> GKTurnBasedMatchmakerViewController {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        let controller = GKTurnBasedMatchmakerViewController(matchRequest: request)
        controller.turnBasedMatchmakerDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: GKTurnBasedMatchmakerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency GKTurnBasedMatchmakerViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
            viewController.dismiss(animated: true)
            onFinish()
        }

        func turnBasedMatchmakerViewController(
            _ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: any Error
        ) {
            viewController.dismiss(animated: true)
            onFinish()
        }
    }
}
#endif
