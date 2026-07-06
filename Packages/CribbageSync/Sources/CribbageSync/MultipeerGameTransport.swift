#if !os(watchOS)
import MultipeerConnectivity
import CribbageKit

/// Local pass-and-play over Multipeer — see docs/plan.md ("watchOS Companion" siblings
/// aside, this is the phone/iPad/Mac-to-phone/iPad/Mac transport). Not available on
/// watchOS: MultipeerConnectivity doesn't ship there at all.
///
/// Connection is intentionally as simple as the trust model calls for: this is two people
/// in the same room, not strangers on the internet, so the hosting side auto-accepts any
/// invitation rather than presenting its own approve/deny UI. The joining side still gets
/// the system's own peer-picker (`MCBrowserViewController`, wired up in CribbageUI), since
/// *finding* the right nearby device is the part actually worth a UI.
@MainActor
public final class MultipeerGameTransport: NSObject, GameTransport {
    /// Bonjour service type: 1-15 chars, lowercase letters/digits/hyphens only.
    public static let serviceType = "fifteentwo-cr"

    public let peerID: MCPeerID
    /// `nonisolated(unsafe)`: MultipeerConnectivity's delegate callbacks arrive on an
    /// arbitrary background queue, not the main actor, and need to read these session/
    /// browser objects synchronously (e.g. to accept an invitation). That's safe here —
    /// these are `let`s set once in `init` and never mutated, and `MCSession`/
    /// `MCNearbyServiceBrowser` already manage their own internal thread safety.
    public nonisolated(unsafe) let session: MCSession
    /// Exposed so CribbageUI can hand it straight to `MCBrowserViewController`, which sets
    /// itself as the browser's delegate — this class deliberately doesn't also conform to
    /// `MCNearbyServiceBrowserDelegate`, so there's only ever one delegate fighting over it.
    public nonisolated(unsafe) let browser: MCNearbyServiceBrowser
    private let advertiser: MCNearbyServiceAdvertiser

    public var onReceiveMove: ((Move) -> Void)?
    public var onConnectedPeersChanged: (([String]) -> Void)?

    public init(displayName: String) {
        peerID = MCPeerID(displayName: displayName)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
    }

    public func startHosting() { advertiser.startAdvertisingPeer() }
    public func stopHosting() { advertiser.stopAdvertisingPeer() }
    public func stopBrowsing() { browser.stopBrowsingForPeers() }

    public func send(_ move: Move) {
        guard !session.connectedPeers.isEmpty, let data = try? JSONEncoder().encode(move) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    public func disconnect() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }
}

extension MultipeerGameTransport: MCSessionDelegate {
    public nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peerNames = session.connectedPeers.map(\.displayName)
        Task { @MainActor in onConnectedPeersChanged?(peerNames) }
    }

    public nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let move = try? JSONDecoder().decode(Move.self, from: data) else { return }
        Task { @MainActor in onReceiveMove?(move) }
    }

    // Unused: this transport only ever sends small JSON move payloads, never streams or
    // file resources.
    public nonisolated func session(
        _ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID
    ) {}
    public nonisolated func session(
        _ session: MCSession, didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID, with progress: Progress
    ) {}
    public nonisolated func session(
        _ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?
    ) {}
}

extension MultipeerGameTransport: MCNearbyServiceAdvertiserDelegate {
    public nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        invitationHandler(true, session)
    }
}
#endif
