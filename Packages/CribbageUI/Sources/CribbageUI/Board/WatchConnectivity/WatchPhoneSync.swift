#if os(watchOS)
import WatchConnectivity
import CribbageBoardKit

/// The watch side of the bridge: receives the phone's authoritative `BoardMatch` via
/// application context, and sends "peg" requests up rather than mutating any state of
/// its own — see `PhoneWatchSync`'s doc comment for the shared design.
@MainActor
final class WatchPhoneSync: NSObject, WCSessionDelegate {
    private let onMatchUpdate: (BoardMatch) -> Void
    private var session: WCSession?

    init(onMatchUpdate: @escaping (BoardMatch) -> Void) {
        self.onMatchUpdate = onMatchUpdate
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func sendPeg(playerIndex: Int, points: Int) {
        guard let session, session.activationState == .activated else { return }
        session.sendMessage(["playerIndex": playerIndex, "points": points], replyHandler: nil, errorHandler: nil)
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["match"] as? Data,
              let match = try? JSONDecoder().decode(BoardMatch.self, from: data) else { return }
        Task { @MainActor in
            onMatchUpdate(match)
        }
    }
}
#endif
