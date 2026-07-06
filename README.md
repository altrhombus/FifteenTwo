# Fifteen Two

An Apple-native cribbage app for iOS, iPadOS, macOS, and watchOS — built to be a fast, beautiful scorekeeper for physical-board games, a real-time coach via camera-based hand scanning, and a genuinely optimal (not heuristic) training partner, alongside SharePlay and local pass-and-play multiplayer.

See [`docs/plan.md`](docs/plan.md) for the full architecture and build plan.

## Status

Early scaffolding — not yet playable.

## Requirements

- Xcode 26.3+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj` is generated from `project.yml` and is not checked into git
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`)

## Building

```sh
xcodegen generate
open FifteenTwo.xcodeproj
```

## License

BSD 3-Clause — see [LICENSE](LICENSE).
