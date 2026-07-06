# Fifteen Two

An Apple-native cribbage app for iOS, iPadOS, macOS, and watchOS — built to be a fast, beautiful scorekeeper for physical-board games, a real-time coach via camera-based hand scanning, and a genuinely optimal (not heuristic) training partner, alongside SharePlay and local pass-and-play multiplayer.

See [`docs/plan.md`](docs/plan.md) for the full architecture and build plan.

## Status

Phases 1–11 of [`docs/plan.md`](docs/plan.md)'s build order are complete: solo play against an exact-solver CPU (with training breakdown and replay), physical board companion mode with SwiftData history, a watchOS companion for the board, adaptive iPad/Mac layouts, Game Center achievements/leaderboards, and Multipeer pass-and-play. SharePlay (Phase 12) is next.

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
- **Multipeer, WatchConnectivity, SharePlay, and camera-based Vision hand-scanning do not work in Simulator.** These need real hardware — two devices for Multipeer/SharePlay testing specifically, signed into two different Apple IDs for SharePlay. Worth lining up a second device/tester before those phases are considered fully verified, not just building-and-launching in Simulator.
- **Multipeer pass-and-play doesn't yet implement the commit-then-reveal fairness check** described in `docs/plan.md`'s RNG & Fairness section. The core sync (both devices converging on identical state via `GameEngine.reduce`) is real and tested; the additional integrity check — the dealing device pre-committing `SHA256(seed)` so the other device can later verify a revealed seed wasn't swapped out — is a documented gap, not a silent omission. Worth its own follow-up pass rather than a half-considered bolt-on.
- **No automated on-device or interactive UI testing.** Verification for each phase has relied on `swift test`, `xcodebuild`, SwiftLint, and Simulator screenshots — real hands-on play-testing (does it *feel* right, does VoiceOver actually read out a full hand correctly, does WatchConnectivity actually sync between two real devices) still needs to happen on your own hardware.

## License

BSD 3-Clause — see [LICENSE](LICENSE).
