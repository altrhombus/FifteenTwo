#if os(iOS)
import WatchConnectivity
import CribbageBoardKit

/// Pushes the current `BoardMatch` to a paired watch via
/// `WCSession.updateApplicationContext` and relays "peg" requests the watch sends back —
/// see docs/plan.md ("watchOS Companion"): the phone stays the source of truth, the
/// watch only ever sends intents, never holds its own authoritative state.
@MainActor
final class PhoneWatchSync: NSObject, WCSessionDelegate {
    private let onPegRequest: (Int, Int) -> Void
    private var session: WCSession?

    init(onPegRequest: @escaping (Int, Int) -> Void) {
        self.onPegRequest = onPegRequest
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func send(_ match: BoardMatch) {
        guard let session, session.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(match) else { return }
        try? session.updateApplicationContext(["match": data])
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?
    ) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let playerIndex = message["playerIndex"] as? Int, let points = message["points"] as? Int else { return }
        Task { @MainActor in
            onPegRequest(playerIndex, points)
        }
    }
}
#endif
