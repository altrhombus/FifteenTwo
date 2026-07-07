# Fifteen Two

An Apple-native cribbage app for iOS, iPadOS, macOS, and watchOS — built to be a fast, beautiful scorekeeper for physical-board games, a real-time coach via camera-based hand scanning, and a genuinely optimal (not heuristic) training partner, alongside SharePlay and local pass-and-play multiplayer.

See [`docs/plan.md`](docs/plan.md) for the full architecture and build plan.

## Status

Every phase in [`docs/plan.md`](docs/plan.md)'s build order is complete, MVP and Post-MVP alike: solo play against an exact-solver CPU, physical board mode, watchOS companion, adaptive iPad/Mac layouts, Game Center achievements/leaderboards, Multipeer + SharePlay pass-and-play, Vision hand-scanning, an App Group-backed widget + Live Activity for board matches, and Game Center turn-based async matchmaking. See Known Limitations below for what's still unverified on real hardware or otherwise pending.

## Requirements

- Xcode 26.3+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj` is generated from `project.yml` and is not checked into git
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`)
- An Apple ID signed into Xcode (Settings > Accounts) — a free Personal Team is enough to build and run locally; the paid Apple Developer Program is only needed for TestFlight and multi-device testing (Multipeer/SharePlay/WatchConnectivity all require real hardware — see Known Limitations below).

## Building

```sh
xcodegen generate
open FifteenTwo.xcodeproj
```

## Known Limitations / Pending Manual Setup

A few things are coded but intentionally incomplete, either because they need a one-time manual step in Xcode/App Store Connect that can't be scripted, or because they need hardware this project hasn't been tested against yet:

- **CloudKit sync is disabled by default.** `CribbageDataStack.makeModelContainer(cloudKitEnabled:)` supports it, but turning it on requires adding the iCloud/CloudKit capability in Xcode's Signing & Capabilities tab first (a real, unscriptable GUI step) — flipping `cloudKitEnabled: true` in `FifteenTwoApp.swift` before that will crash at launch.
- **Game Center achievements/leaderboards won't register yet.** `GameCenterReporter` (in `CribbageUI`) is fully wired up and the entitlement is in place, but the achievement/leaderboard identifiers it reports to (`com.altrhombus.FifteenTwo.achievement.*` / `.leaderboard.*`) need matching entries created in App Store Connect before Game Center will actually accept them. Until then, every report call fails silently rather than crashing.
- **Multipeer, WatchConnectivity, SharePlay, Game Center turn-based matches, and camera-based Vision hand-scanning do not work in Simulator.** These need real hardware — two devices (or two Game Center accounts, for turn-based) for testing specifically, signed into two different Apple IDs for SharePlay. Worth lining up a second device/tester before those phases are considered fully verified, not just building-and-launching in Simulator.
- **Vision hand-scanning auto-detects rank, red/black color, and (for red cards) hearts vs. diamonds — but not the exact suit for black cards.** The plan's original design called for a small trained CoreML suit classifier, but training one needs real photographed playing cards this project has no way to gather (no camera, no physical deck available in this environment). `SuitColorDetector` covers red/black (a robust heuristic needing no training data) and `SuitShapeAnalyzer` covers hearts-vs-diamonds via shape convexity (diamonds are the only fully convex suit symbol) — both real, deterministic, untrained techniques. Clubs vs. spades is deliberately not attempted: both have concave notches and a stem, and that split is much shakier to automate reliably without real photos to tune against. The confirmation screen always has the person pick the exact suit regardless, and the convexity threshold itself is verified only against synthetic test shapes, not real printed cards. Checked whether Apple Intelligence's on-device model could fill the remaining gap (WWDC 2026 announced multimodal image input for the Foundation Models framework) — verified against the actual installed SDK (Xcode 26.6) and confirmed that capability isn't present in this framework yet (`Transcript.Segment` only has `.text`/`.structure` cases, no image case); `VisualIntelligence.framework` is a different thing (registers your app with the system's own camera-intelligence UI, not a callable "classify this image" API). Worth revisiting once a newer SDK actually ships it.
- **Neither Multipeer nor SharePlay pass-and-play implements the commit-then-reveal fairness check** described in `docs/plan.md`'s RNG & Fairness section. The core sync (both devices converging on identical state via `GameEngine.reduce`, shared by both transports through `MultiplayerSessionController`) is real and tested; the additional integrity check — the dealing device pre-committing `SHA256(seed)` so the other device can later verify a revealed seed wasn't swapped out — is a documented gap, not a silent omission. Worth its own follow-up pass rather than a half-considered bolt-on.
- **SharePlay's seat assignment (who's playerOne) has no negotiation protocol beyond sorting participant UUIDs.** This is deterministic and works for exactly two participants, but a third person joining the same FaceTime call and opening the activity has no defined role — they'd just see a perpetual "waiting" state. Fine for the intended two-player game, not handled gracefully beyond that.
- **No automated on-device or interactive UI testing.** Verification for each phase has relied on `swift test`, `xcodebuild`, SwiftLint, and Simulator screenshots — real hands-on play-testing (does it *feel* right, does VoiceOver actually read out a full hand correctly, does WatchConnectivity actually sync between two real devices) still needs to happen on your own hardware.
- **The board-match Live Activity's Lock Screen/Dynamic Island rendering hasn't been visually verified.** Build succeeds and the start/update/end lifecycle is wired into `BoardSessionController`, but actually seeing it appear needs starting a real board match and checking the Lock Screen or Dynamic Island by hand (not something safely scriptable via blind Simulator taps) — same category of manual-verification gap as VoiceOver and WatchConnectivity above.
- **The shared App Group container (`group.com.altrhombus.FifteenTwo`) is iOS-only for now** — `FifteenTwo-macOS` doesn't have the entitlement, since App Groups interact with App Sandbox on macOS (which this target doesn't currently enable) and there's no macOS widget yet to justify sorting that out. `CribbageDataStack`'s `useAppGroup` parameter defaults to `false` for exactly this reason — the same crash-without-entitlement risk as CloudKit.
- **Game Center turn-based matchmaking is iOS-only** and hasn't been played end-to-end. `TurnBasedMatchController`/`TurnBasedMatchListController`/the matchmaker UI all build and the engine-level turn-order logic (`GameEngine.seatToActNext`) is unit tested, but actually completing a full match needs two real Game Center accounts taking alternating turns, which hasn't been exercised.

## License

BSD 3-Clause — see [LICENSE](LICENSE).
