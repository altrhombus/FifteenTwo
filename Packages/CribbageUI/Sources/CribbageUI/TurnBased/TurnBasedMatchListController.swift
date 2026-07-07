#if os(iOS)
import Observation
@preconcurrency import GameKit

/// Loads and keeps a list of the local player's turn-based matches, refreshing whenever
/// Game Center notifies this device of a turn event (the app opening, a turn being passed
/// to it, an accepted invite, etc.) — see `GKTurnBasedEventListener`.
@Observable
@MainActor
public final class TurnBasedMatchListController {
    public private(set) var matches: [GKTurnBasedMatch] = []
    public private(set) var errorMessage: String?

    private var listener: Listener?

    public init() {
        let listener = Listener { [weak self] in
            Task { await self?.refresh() }
        }
        GKLocalPlayer.local.register(listener)
        self.listener = listener
    }

    /// Called from the view's `.onDisappear` rather than relying on `deinit` — `deinit` is
    /// always `nonisolated`, even for a `@MainActor` class, which makes it an awkward
    /// place to touch GameKit's registration API safely.
    public func stopListening() {
        guard let listener else { return }
        GKLocalPlayer.local.unregisterListener(listener)
        self.listener = nil
    }

    public func refresh() async {
        do {
            // Apple's auto-synthesized `async` overlay for this completion-handler API,
            // rather than a hand-written `withCheckedThrowingContinuation` -- the latter
            // requires `[GKTurnBasedMatch]` to be `Sendable` as a hard stdlib constraint
            // on `CheckedContinuation` itself, which `@preconcurrency import` (a GameKit-
            // side relaxation) can't relax.
            matches = try await GKTurnBasedMatch.loadMatches()
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load matches: \(error.localizedDescription)"
        }
    }

    /// A tiny standalone class rather than making `TurnBasedMatchListController` itself
    /// conform to `GKLocalPlayerListener` — registering `self` directly would keep a
    /// strong reference cycle-adjacent relationship with GameKit for this object's whole
    /// lifetime; a small owned listener forwarding back via a weak closure avoids that.
    @MainActor
    private final class Listener: NSObject, @preconcurrency GKLocalPlayerListener {
        let onTurnEvent: () -> Void
        init(onTurnEvent: @escaping () -> Void) { self.onTurnEvent = onTurnEvent }

        func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
            onTurnEvent()
        }

        func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
            onTurnEvent()
        }
    }
}
#endif
