#if os(iOS)
import Foundation
import Observation
@preconcurrency import GameKit
import CribbageKit

/// Drives one Game Center turn-based match — see docs/plan.md's Game Center section:
/// `GKTurnBasedMatch` is store-and-forward, not a live session, so this doesn't reuse
/// `GameTransport`/`MultiplayerSessionController` at all. The entire `GameState` is
/// encoded as the match's `matchData` (not a move log): turn-based play only ever needs
/// "the current complete state," never a stream of individual moves to replay.
///
/// Only one participant can ever be active at a time in a turn-based match, unlike
/// solo/live play where both seats can act "simultaneously" during discarding — see
/// `GameEngine.seatToActNext(in:)`, which this calls after every move to decide who the
/// match hands off to next.
@Observable
@MainActor
public final class TurnBasedMatchController {
    public let match: GKTurnBasedMatch
    public private(set) var state: GameState
    public let mySeat: Seat
    public private(set) var errorMessage: String?

    private init(match: GKTurnBasedMatch, state: GameState, mySeat: Seat) {
        self.match = match
        self.state = state
        self.mySeat = mySeat
    }

    public static func load(_ match: GKTurnBasedMatch) async throws -> TurnBasedMatchController {
        let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, Error>) in
            match.loadMatchData { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }

        let state: GameState
        if let data, !data.isEmpty {
            state = try JSONDecoder().decode(GameState.self, from: data)
        } else {
            // GameKit itself designates which participant goes first via
            // `currentParticipant` — the initial dealer here must match that (not just
            // default to .playerOne), or `seatToActNext` will disagree with who GameKit
            // actually authorizes to call `endTurn`, and the very first turn will fail.
            let initialDealer = seatIndex(of: match.currentParticipant, in: match) ?? .playerOne
            state = GameState(ruleset: .standard, dealer: initialDealer)
        }
        let localParticipant = match.participants.first { $0.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID }
        let mySeat = seatIndex(of: localParticipant, in: match) ?? .playerOne
        return TurnBasedMatchController(match: match, state: state, mySeat: mySeat)
    }

    /// `.playerOne`/`.playerTwo` mapped to a participant's fixed position in
    /// `match.participants` — stable once GameKit creates the match.
    private static func seatIndex(of participant: GKTurnBasedParticipant?, in match: GKTurnBasedMatch) -> Seat? {
        guard let participant,
              let index = match.participants.firstIndex(where: { $0 === participant })
        else { return nil }
        return index == 0 ? .playerOne : .playerTwo
    }

    public var opponentSeat: Seat { mySeat.opponent }
    public var isMyTurn: Bool { GameEngine.seatToActNext(in: state) == mySeat }
    public var legalMyPlays: [Card] { GameEngine.legalPlays(for: mySeat, in: state) }

    public func dealIfMyTurn() async {
        guard state.phase == .dealing, isMyTurn else { return }
        await apply(.dealHand(seed: .random()))
    }

    public func discard(_ cards: [Card]) async {
        await apply(.discard(seat: mySeat, cards: cards))
    }

    public func cutForStarterIfMyTurn() async {
        guard isMyTurn else { return }
        await apply(.cutForStarter)
    }

    public func play(_ card: Card) async {
        await apply(.playCard(seat: mySeat, card: card))
    }

    public func sayGo() async {
        await apply(.sayGo(seat: mySeat))
    }

    // MARK: - Muggins (interactive counting)

    /// The counting decision owed by the local player, if it's their turn in the show.
    public var myPendingCount: PendingCount? {
        guard state.phase == .counting, let pending = state.pendingCount, pending.actor == mySeat else {
            return nil
        }
        return pending
    }

    public func claimScore(_ points: Int) async {
        guard myPendingCount?.stage == .awaitingClaim else { return }
        await apply(.claimScore(seat: mySeat, points: points))
    }

    public func callMuggins() async {
        guard myPendingCount?.stage == .awaitingMuggins else { return }
        await apply(.callMuggins(seat: mySeat))
    }

    public func passMuggins() async {
        guard myPendingCount?.stage == .awaitingMuggins else { return }
        await apply(.passMuggins(seat: mySeat))
    }

    private func apply(_ move: Move) async {
        state = GameEngine.reduce(state, applying: move)
        guard let data = try? JSONEncoder().encode(state) else { return }

        do {
            if state.phase == .gameOver {
                setMatchOutcomes()
                try await endMatch(with: data)
            } else if let nextSeat = GameEngine.seatToActNext(in: state),
                      let nextParticipant = participant(for: nextSeat) {
                try await endTurn(nextParticipant: nextParticipant, data: data)
            }
        } catch {
            errorMessage = "Couldn't submit your turn: \(error.localizedDescription)"
        }
    }

    private func participant(for seat: Seat) -> GKTurnBasedParticipant? {
        let index = seat == .playerOne ? 0 : 1
        guard match.participants.indices.contains(index) else { return nil }
        return match.participants[index]
    }

    private func setMatchOutcomes() {
        guard let winner = state.winner else { return }
        for (index, participant) in match.participants.enumerated() {
            let seat: Seat = index == 0 ? .playerOne : .playerTwo
            participant.matchOutcome = seat == winner ? .won : .lost
        }
    }

    private func endTurn(nextParticipant: GKTurnBasedParticipant, data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            match.endTurn(
                withNextParticipants: [nextParticipant], turnTimeout: GKTurnTimeoutDefault, match: data
            ) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    private func endMatch(with data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            match.endMatchInTurn(withMatch: data) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }
}
#endif
