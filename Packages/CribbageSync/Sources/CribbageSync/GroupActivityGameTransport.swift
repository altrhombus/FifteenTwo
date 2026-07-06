#if !os(watchOS)
import GroupActivities
import CribbageKit

/// The shareable SharePlay activity — see docs/plan.md ("SharePlay"): registering this is
/// what lets the system offer "Play Fifteen Two" during an active FaceTime call.
public struct FifteenTwoGroupActivity: GroupActivity {
    public static let activityIdentifier = "com.altrhombus.FifteenTwo.pass-and-play"

    public var metadata: GroupActivityMetadata {
        get async {
            var metadata = GroupActivityMetadata()
            metadata.title = "Fifteen Two"
            metadata.subtitle = "Play cribbage together"
            metadata.type = .generic
            return metadata
        }
    }

    public init() {}
}

/// SharePlay conformance of `GameTransport` — the second proof (after Multipeer) that the
/// transport abstraction holds: same protocol, same `GameEngine.reduce` one layer up, only
/// the plumbing underneath differs. See docs/plan.md ("State & Sync").
///
/// Not available on watchOS: `GroupActivity`'s session/messaging APIs are marked
/// unavailable there in the framework itself.
@MainActor
public final class GroupActivityGameTransport: GameTransport {
    public var onReceiveMove: ((Move) -> Void)?
    /// Fires with the current participant count whenever it changes — the UI uses this to
    /// know when someone else has actually joined the SharePlay session.
    public var onParticipantsChanged: ((Int) -> Void)?

    /// Unlike Multipeer's explicit host/join UI, everyone in the FaceTime call sees the
    /// same "Play Fifteen Two" prompt — there's no inherent "who's playerOne" signal. Once
    /// exactly two participants are active, both devices independently sort participant
    /// IDs and assign seats identically, with no negotiation round-trip needed. `nil`
    /// until that's happened.
    public private(set) var mySeat: Seat?

    private var messenger: GroupSessionMessenger?
    private var session: GroupSession<FifteenTwoGroupActivity>?
    private var tasks: [Task<Void, Never>] = []

    public init() {}

    /// Offers the activity for sharing — during an active FaceTime call, this triggers
    /// the system's own SharePlay prompt. Returns `false` outside a call or if the person
    /// declines; `observeSessions()` is what actually picks up the resulting session
    /// (whether from this device activating it, or another participant already having
    /// started one).
    @discardableResult
    public func activate() async -> Bool {
        let activity = FifteenTwoGroupActivity()
        switch await activity.prepareForActivation() {
        case .activationPreferred:
            return (try? await activity.activate()) ?? false
        case .activationDisabled, .cancelled:
            return false
        @unknown default:
            return false
        }
    }

    /// Starts listening for `GroupSession`s. Call once per screen; safe to call before or
    /// after (or without ever calling) `activate()`, since a session can also arrive
    /// because someone else in the FaceTime call started it.
    public func observeSessions() {
        let task = Task {
            for await session in FifteenTwoGroupActivity.sessions() {
                configure(session)
            }
        }
        tasks.append(task)
    }

    private func configure(_ session: GroupSession<FifteenTwoGroupActivity>) {
        let messenger = GroupSessionMessenger(session: session, deliveryMode: .reliable)
        self.messenger = messenger
        self.session = session

        let receiveTask = Task {
            for await (move, _) in messenger.messages(of: Move.self) {
                onReceiveMove?(move)
            }
        }
        tasks.append(receiveTask)

        let participantsTask = Task {
            for await participants in session.$activeParticipants.values {
                assignSeatIfNeeded(session: session, participants: participants)
                onParticipantsChanged?(participants.count)
            }
        }
        tasks.append(participantsTask)

        session.join()
    }

    private func assignSeatIfNeeded(
        session: GroupSession<FifteenTwoGroupActivity>, participants: Set<Participant>
    ) {
        guard mySeat == nil, participants.count >= 2 else { return }
        let firstTwoIDs = participants.map(\.id.uuidString).sorted().prefix(2)
        guard let myIndex = firstTwoIDs.firstIndex(of: session.localParticipant.id.uuidString) else { return }
        mySeat = myIndex == firstTwoIDs.startIndex ? .playerOne : .playerTwo
    }

    public func send(_ move: Move) {
        guard let messenger else { return }
        Task { try? await messenger.send(move) }
    }

    public func leave() {
        session?.leave()
        for task in tasks { task.cancel() }
        tasks.removeAll()
        messenger = nil
        session = nil
    }
}
#endif
