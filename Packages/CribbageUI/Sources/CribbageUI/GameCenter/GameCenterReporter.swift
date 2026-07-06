#if !os(watchOS)
import GameKit
import CribbageKit
import CribbageBoardKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Achievements and leaderboards — a thin layer reacting to state transitions that
/// already exist (a solo win/skunk/perfect hand, a completed board match), following the
/// same pattern as `AccessibilityAnnouncer`: no changes to `CribbageKit`/`CribbageBoardKit`
/// at all. See docs/plan.md's Game Center section.
///
/// The identifiers below don't do anything until they're created to match in App Store
/// Connect (same category of manual, unscriptable dashboard step as the CloudKit
/// capability) — every GameKit call here fails silently until then, so this is safe to
/// ship ahead of that setup.
@MainActor
public enum GameCenterReporter {
    private enum AchievementID {
        static let firstWin = "com.altrhombus.FifteenTwo.achievement.firstWin"
        static let skunkVictory = "com.altrhombus.FifteenTwo.achievement.skunkVictory"
        static let perfectHand = "com.altrhombus.FifteenTwo.achievement.perfectHand"
        static let firstBoardMatch = "com.altrhombus.FifteenTwo.achievement.firstBoardMatch"
    }

    private enum LeaderboardID {
        static let soloWins = "com.altrhombus.FifteenTwo.leaderboard.soloWins"
        static let boardMatchesCompleted = "com.altrhombus.FifteenTwo.leaderboard.boardMatchesCompleted"
    }

    private enum DefaultsKey {
        static let soloWinCount = "GameCenterReporter.soloWinCount"
        static let boardMatchCount = "GameCenterReporter.boardMatchCount"
    }

    /// Call once at app launch. Presents Apple's own sign-in sheet if the player isn't
    /// already signed in; if Game Center is disabled (e.g. parental controls) GameKit
    /// hands back a nil view controller and a non-nil error, and this just does nothing.
    public static func authenticateLocalPlayer() {
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            if let viewController {
                #if os(iOS)
                presentOniOS(viewController)
                #elseif os(macOS)
                presentOnMacOS(viewController)
                #endif
            }
            GKAccessPoint.shared.isActive = GKLocalPlayer.local.isAuthenticated
        }
    }

    /// Solo play only: unlike the board companion, the signed-in Game Center player is
    /// unambiguously `humanSeat`, so win-conditioned achievements/leaderboards make sense
    /// here in a way they don't for the two-real-people board mode below.
    public static func reportSoloGameCompleted(winner: Seat, humanSeat: Seat, skunkResult: SkunkResult?) {
        guard winner == humanSeat else { return }
        report(achievement: AchievementID.firstWin)
        if skunkResult == .skunk || skunkResult == .doubleSkunk {
            report(achievement: AchievementID.skunkVictory)
        }
        incrementAndSubmit(countKey: DefaultsKey.soloWinCount, leaderboardID: LeaderboardID.soloWins)
    }

    /// Checked on every hand, not just game-over, since a 29-point hand doesn't
    /// necessarily end the game. Only the human's own hand counts — a 29 can only occur
    /// in a *hand* (needs three 5s + the matching-suit jack, with the cut as the fourth
    /// 5), never the crib, so there's no crib case to check here.
    public static func reportHandCounted(_ summary: RoundSummary, dealer: Seat, humanSeat: Seat) {
        let humanHand = dealer == humanSeat ? summary.dealerHand : summary.nonDealerHand
        guard humanHand?.total == 29 else { return }
        report(achievement: AchievementID.perfectHand)
    }

    /// Board mode has no concept of "the app's player" — it's a scorekeeper for two real
    /// people sharing one phone/watch, and the signed-in Game Center player could be
    /// either of them or neither by name. So this is participation-based (any completed
    /// match), not tied to who won.
    public static func reportBoardMatchCompleted(_ match: BoardMatch) {
        guard match.isComplete else { return }
        report(achievement: AchievementID.firstBoardMatch)
        incrementAndSubmit(countKey: DefaultsKey.boardMatchCount, leaderboardID: LeaderboardID.boardMatchesCompleted)
    }

    private static func report(achievement id: String, percentComplete: Double = 100) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { _ in }
    }

    /// Leaderboard scores aren't additive server-side, so the running total is tracked
    /// locally (plain UserDefaults — this is reporting glue, not data worth a SwiftData
    /// model) and resubmitted as the new value each time.
    private static func incrementAndSubmit(countKey: String, leaderboardID: String) {
        let defaults = UserDefaults.standard
        let newCount = defaults.integer(forKey: countKey) + 1
        defaults.set(newCount, forKey: countKey)
        guard GKLocalPlayer.local.isAuthenticated else { return }
        GKLeaderboard.submitScore(
            newCount, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID]
        ) { _ in }
    }

    #if os(iOS)
    private static func presentOniOS(_ viewController: UIViewController) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.rootViewController
        else { return }
        root.present(viewController, animated: true)
    }
    #elseif os(macOS)
    private static func presentOnMacOS(_ viewController: NSViewController) {
        NSApplication.shared.windows.first?.contentViewController?.presentAsSheet(viewController)
    }
    #endif
}
#endif
