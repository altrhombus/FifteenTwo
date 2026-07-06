#if !os(watchOS)
import SwiftUI
import CribbageKit

/// The thin platform layer over `AnnouncementBuilder` — see docs/plan.md
/// ("Accessibility"): centralizing the actual posting call here means the four platforms'
/// differences are absorbed in one place instead of scattered through every view.
/// SwiftUI's `AccessibilityNotification.Announcement` is used directly (no
/// UIKit/AppKit branching needed) since it's available across all our platform targets.
enum AccessibilityAnnouncer {
    @MainActor
    static func announce(before: GameState, after: GameState, move: Move, listenerSeat: Seat) {
        let lines = AnnouncementBuilder.announcements(
            before: before, after: after, move: move, listenerSeat: listenerSeat
        )
        for line in lines {
            AccessibilityNotification.Announcement(line).post()
        }
    }
}
#endif
