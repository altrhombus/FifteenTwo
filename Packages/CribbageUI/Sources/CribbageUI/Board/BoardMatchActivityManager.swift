#if os(iOS)
// `Activity<Attributes>` isn't marked `Sendable` in ActivityKit's own interface (unlike
// `ActivityContent`, which is audited) -- `@preconcurrency` tells the compiler to trust
// this not-yet-fully-audited framework's types rather than reject every Task closure
// that touches one.
@preconcurrency import ActivityKit
import CribbageBoardKit

/// Starts/updates/ends the Live Activity for an in-progress physical board match — see
/// docs/plan.md's Post-MVP "Widgets/Live Activities" item. A thin platform layer reacting
/// to match state changes, same pattern as `AccessibilityAnnouncer`/`GameCenterReporter`:
/// no changes to `CribbageBoardKit`'s actual match logic.
@MainActor
enum BoardMatchActivityManager {
    private static var currentActivity: Activity<BoardMatchActivityAttributes>?

    /// The single entry point — safe to call after every change to a match, in any
    /// state. Starts a fresh activity for a new (or reopened-after-completion) match,
    /// updates the running one otherwise, and ends it once the match completes.
    static func sync(with match: BoardMatch) {
        if currentActivity?.attributes.matchID != match.id {
            start(for: match)
            return
        }
        if match.isComplete {
            end(finalMatch: match)
        } else {
            update(for: match)
        }
    }

    /// Call when leaving board mode entirely (not just finishing a match) to dismiss any
    /// Live Activity immediately rather than leaving it to linger.
    static func dismiss() {
        end()
    }

    private static func start(for match: BoardMatch) {
        end()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = BoardMatchActivityAttributes(
            playerOneName: match.players[0].name, playerTwoName: match.players[1].name, matchID: match.id
        )
        let content = ActivityContent(state: BoardMatchActivityAttributes.ContentState(match: match), staleDate: nil)
        currentActivity = try? Activity.request(attributes: attributes, content: content)
    }

    private static func update(for match: BoardMatch) {
        guard let currentActivity else { return }
        let content = ActivityContent(state: BoardMatchActivityAttributes.ContentState(match: match), staleDate: nil)
        Task { await currentActivity.update(content) }
    }

    /// Ends the current activity, if any. Passing the completed `match` shows its final
    /// score for an hour before the system removes it, matching how most Live Activities
    /// (e.g. delivery tracking) linger briefly after completion rather than vanishing
    /// instantly.
    private static func end(finalMatch: BoardMatch? = nil) {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        Task {
            if let finalMatch {
                let state = BoardMatchActivityAttributes.ContentState(match: finalMatch)
                let content = ActivityContent(state: state, staleDate: nil)
                await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(60 * 60)))
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
