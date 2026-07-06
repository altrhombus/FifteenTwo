# Fifteen Two — Cribbage App Architecture & Build Plan

## Context

There's no shortage of cribbage scorekeeper apps, but none combine what Apple's platform actually enables: a physical-board companion with a watch peg-tapper, computer-vision hand recognition that turns a phone into a coach for an IRL game, zero-account local multiplayer, and genuinely optimal (not heuristic) training analysis — all wrapped in first-class accessibility and auditable randomness. That combination is the differentiator worth building toward.

This is a from-scratch project (no existing code). The goal of this plan is to lock in an architecture *now* that lets every headline feature you listed — physical board mode + Watch, Vision hand-scanning, local pass-and-play, SharePlay, CPU opponent/training — share one core engine instead of becoming five disconnected implementations, while still being learnable incrementally since this is your first project at this depth on Apple's platforms. Widgets/Live Activities are the one item still deliberately deferred past MVP, but the architecture below is shaped so it doesn't require a rewrite when its turn comes.

The one framing decision everything else follows from: **build a pure-Swift, UI-free core engine (rules, scoring, solvers, RNG, state machine) and treat every platform target as a thin renderer over it.** This is what makes "ship on iOS/iPadOS/macOS/watchOS" realistic without four parallel implementations of the actual game logic.

## Working Style: Vibe-Coded, Interactively Built

This is being built with Claude writing the Swift interactively, phase by phase — you're testing and giving feedback (in Xcode, on-device, in the simulator) rather than writing or reviewing the code line-by-line. You'll pick up Swift on the side as a byproduct of watching it get built and poking at it, but learning Swift is not a gate on any phase below.

That workflow shift changes where the safety net comes from: since you won't be catching bugs by reading the code, correctness has to be demonstrated another way at each step — automated tests (`swift test`) for the engine, a runnable build you can actually play after every phase, and your own play-testing feedback as the real review process. This makes two things more important, not less:

- **Connect Xcode's built-in MCP server if possible.** Xcode 26.3+ ships a built-in Model Context Protocol server (`mcpbridge`) exposing build, test-run, and compiler-diagnostics tools to AI assistants. If it's connected to this Claude Code session (worth checking/setting up as part of Phase 1), Claude can build, run tests, and read real compiler diagnostics directly — closing the loop on compile errors and test failures without you needing to relay them manually. That frees your testing time for what actually needs a human: does the game feel right, is the UI delightful, does a play-through surface a rules or UX problem — not catching typos or build breaks.

- **Cribbage fluency still matters, maybe more.** You're the one who has to notice "that doesn't feel right" when playing a build, since you're not reading the scoring code to catch a bug. Play a good number of real hands (physical board, or an existing app) so you have the intuition to catch something off during testing. When the engine is built, it'll still be validated against the official American Cribbage Congress rules and known reference hand corpora — but your own hands-on feel for the game is the other half of the safety net.
- **Every phase should end in something you can run and react to.** Since feedback replaces code review as the main correctness check, the build order below is kept incremental specifically so there's always a testable build in your hands, not just for pedagogical pacing.

## Design Language: Liquid Glass, Refined by Golden Gate

Beauty is a stated prerequisite, not a nice-to-have — the bar is Apple Design Award-caliber craft: delight, surprise, and platform-native idioms rather than a cross-platform lowest-common-denominator UI. Concretely, that means building natively against Apple's current design language rather than a custom look:

- **Liquid Glass** (introduced iOS/macOS 26 "Tahoe," WWDC 2025) is the foundational material system — translucent, dynamic, light-bending ("lensing" rather than plain blur) chrome that floats above solid content. **macOS Golden Gate (macOS 27, WWDC 2026)** doesn't replace this, it refines it: better contrast/readability, a user-facing Liquid Glass transparency slider, uniform toolbars, sidebars that stretch to the window edge with colorized icons, tighter corner radii, and more pronounced shadow/depth. Building against the official SwiftUI APIs (below) means these refinements land essentially for free on recompile, rather than needing to be chased by hand.
- **The core pattern, straight from Apple's own guidance, maps unusually well onto a card game**: glass is meant for the floating navigation/chrome layer, while real content stays solid underneath. That's exactly the right split here — the score HUD, pegging-count display, and toolbar controls are the floating glass layer (`.glassEffect(_:in:)`, grouped via `GlassEffectContainer` where multiple glass elements need to visually merge/morph, e.g. an expanding score breakdown), while the cards, board, and pegging track stay opaque and fully legible on the base layer. Cards should never sit *under* glass — legibility for a card game is non-negotiable, and this is also literally Apple's own recommended pattern, not a workaround.
- **This isn't a separate concern from accessibility** — using the official glass APIs rather than hand-rolled blur/vibrancy means Reduce Transparency and Reduce Motion are respected automatically by the system, which is one more reason not to hand-roll custom glass effects.
- **Required viewing before UI work starts** (Phase 3 below): the WWDC 2025 session ["Build a SwiftUI app with the new design"](https://developer.apple.com/videos/play/wwdc2025/323/) — it's the primary source for `glassEffect`/`GlassEffectContainer`/`glassEffectID` usage patterns referenced above.

## Prerequisite Tooling

Checked what's actually on this machine rather than assuming:

- **Xcode.app is already installed** (`/Applications/Xcode.app`) with macOS, iOS/iPadOS, watchOS, and tvOS platform SDKs present (a visionOS SDK is also there, unused — not a target of this plan). The only loose end: `xcode-select -p` currently points at the standalone Command Line Tools rather than the full Xcode install, so `xcodebuild` won't run until it's repointed — `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, then accept the license with `sudo xcodebuild -license`. One command, not a download.
- **Xcode's native Claude/MCP integration is already added on this machine.** The expected workflow is still primarily *external* — this Claude Code session driving the work, with Xcode/Simulator/device used to actually build, run, and test — rather than routing through Xcode's embedded Claude panel. Worth revisiting during Phase 1 whether connecting that native integration to this session (vs. using it standalone inside Xcode) is worth the setup, but it's not a blocker either way; plain `xcodebuild`/`swift test` from the command line works regardless.
- **Already installed via Homebrew, nothing to do**: `git` (2.55.0), `gh` (2.95.0, the GitHub CLI — ready for the repo creation/push in Phase 1).
- **Worth installing via Homebrew as part of Phase 1**: `brew install xcodegen` — generates the `.xcodeproj`/`.xcworkspace` files from a version-controlled YAML spec instead of Claude hand-editing Xcode's notoriously merge-conflict-prone binary/XML project format directly. The YAML spec is what actually lives in git; the generated project files are gitignored and regenerated on demand. This matters more here than in a typical project given how much project-structure editing (new targets, new packages) this plan involves.
- **Worth installing for code quality, low-priority/anytime before Phase 2**: `brew install swiftlint` (linting) and, optionally, `brew install swift-format` (formatting) — cheap safety nets given you won't be reading every line of Swift yourself.
- **Later, optional**: `brew install fastlane` if/when TestFlight uploads (Phase 3 milestone onward) are worth automating rather than doing manually through Xcode's Organizer.

## Repository Setup

- Local path: `/Users/altrhombus/Projects/repos/public/FifteenTwo` (already created, empty).
- GitHub repo: public, named `FifteenTwo`, licensed **BSD 3-Clause** (permissive, plus a non-endorsement clause protecting against derivative works implying your endorsement).
- Standard Xcode/Swift `.gitignore` (excludes `.build/`, `DerivedData/`, `*.xcuserstate`, etc.) plus a `LICENSE` file and a minimal `README.md` set up as part of Phase 1 scaffolding, before any real engine code is written.

## Project Structure

Xcode workspace with local Swift Packages, not one monolithic app target:

```
FifteenTwo.xcworkspace
├── Packages/
│   ├── CribbageKit/         pure Swift: Card/Hand/Deck/Ruleset, Scorer, DiscardSolver,
│   │                        PeggingSolver, seeded RNG + fairness proof, GameState/Move/GameEngine,
│   │                        AnnouncementBuilder (accessibility text, no UIAccessibility calls)
│   ├── CribbageBoardKit/    pure Swift, deliberately independent of CribbageKit's card model —
│   │                        Peg/BoardMatch/SkunkRules for the physical-board scorekeeper
│   ├── CribbageSync/        GameTransport protocol + MultipeerGameTransport + GroupActivityGameTransport
│   │                        (SharePlay) — both are conformances of the same transport protocol
│   ├── CribbageVision/      later phase — rectangle detection, perspective correction,
│   │                        suit classifier, scan session
│   ├── CribbageData/        SwiftData — match history, SRS drill stats, settings
│   └── CribbageUI/          shared SwiftUI views where iOS/iPadOS/macOS realistically overlap
├── App-iOS/    App-macOS/    Watch/    Widgets/ (extension point reserved, not built in MVP)
```

`CribbageKit` has zero platform imports, so its correctness (the part that matters most) is verified with `swift test` in seconds — no simulator needed. `CribbageBoardKit` is kept separate on purpose: the physical-board tally counter has no cards/deck/crib, and coupling it to the full rules engine would add complexity for nothing. `CribbageSync` depends only on `CribbageKit`'s `GameState`/`Move` types, never on how a move was decided — which is exactly what lets Multipeer and, later, SharePlay both be "just another transport."

## Core Engine

**Data model**: `Card`/`Rank`/`Suit` as simple `Codable` value types; a `Ruleset` struct (game target 121, skunk/double-skunk thresholds, muggins toggle) passed into the engine rather than hardcoded, since house rules vary.

**Scoring** (`Scorer.score(hand:starter:isCrib:ruleset:) -> ScoreBreakdown`): pure function returning itemized `ScoreEvent`s (not just a total), since the training screen needs to show *what* scored. Special-case the crib flush rule (needs all 5 cards, vs. 4-or-5 for a hand) — a classic cribbage-engine bug.

**Rules accuracy is non-negotiable — no guessing.** The base ruleset is implemented against an authoritative rules source (the official American Cribbage Congress rules), not reconstructed from memory, precisely because subtle regional/edge-case differences (crib-flush card count, exactly when "his nobs" applies, "go"/31 scoring, run-of-3+ requiring genuinely distinct ranks, etc.) are easy to get subtly wrong without one. Every scoring rule gets implemented with the source rule text checked at implementation time, and validated against a battery of known-canonical hands with published expected scores (the 29-point maximum, a 0-point "fish" hand, and other widely-documented reference hands), plus cross-checked where possible against the test vectors of established open-source cribbage scoring engines as an independent second source of truth. If a rule is ever ambiguous or a house variant is unclear, that's a question back to you, not an assumption baked in silently.

**Discard solver — confirmed exact and real-time, not aspirational.** Choosing 2 discards from 6 cards is `C(6,2) = 15` combinations. For each candidate: hand EV averages `Scorer.score` over the 46 unseen cards; crib EV additionally averages over the opponent's unknown 2-card crib contribution from the remaining 45 (`C(45,2) = 990`). Total ≈ 690 + 683,100 ≈ **684,000 scoring calls**, each doing bounded O(1)-ish work — comfortably tens of milliseconds on any iPhone or Mac. This is the engine that powers CPU discard choice, the post-game EV breakdown, and "practice this hand again."

**Pegging solver — exact where both hands are known, expectation-optimal where they aren't (state this distinction explicitly in-app, don't overclaim).** With both hands known (post-game analysis, replay), pegging's small tree (≤4 cards/hand, count-≤31 legality, "go" pruning) is exhaustively minimax-searchable in well under a millisecond. Live CPU play faces genuine hidden information — the opponent's hand is one of roughly `C(41,4) ≈ 100,000` possibilities — so the same minimax core runs via Monte Carlo sampling (a few hundred plausible opponent hands) rather than full enumeration, for perceptible-lag-free play. One engine, two calling conventions, correctly labeled: **discard EV and both-hands-known pegging analysis are exact; live CPU pegging is expectation-optimal under sampling**, which is real optimal play under uncertainty and well above a heuristic bot.

**One engine, three consumers, no duplicated logic**: CPU move selection, the training/EV-breakdown screen, and hand replay all call the same `DiscardSolver`/`PeggingSolver`/`GameEngine.reduce` functions — never a second parallel implementation.

**CPU difficulty tiers, not just optimal.** An always-perfect solver is a discouraging opponent for a player who's still learning strategy — which, per above, is also you right now. Add a difficulty parameter that injects controlled noise (e.g. sample from the top-*k* discard/pegging options weighted by EV, rather than always taking the single best) so there's an approachable tier to actually enjoy playing against while the "optimal" tier remains available for the training/analysis screens where exactness is the point.

## House Rules: Correct Base, Configurable Variants

The base game is always standard rules — accurate first, flexible second. `Ruleset` (already introduced above) is deliberately the *only* seam where variation is allowed: every house-rule toggle lives there as an explicit, named, tested option, never as an ad hoc special case scattered through `Scorer` or `GameEngine`. Concretely worth supporting as toggles from the start, since they're common and low-risk (pure threshold/behavior switches, not structural changes):

- Skunk (91) / double-skunk (61) score thresholds — already in `Ruleset`.
- Muggins (opponent may claim points you missed) on/off — already in `Ruleset`.
- Whether "the go" (last card, count under 31) scores 1 point vs. count-of-31-exactly scoring 2 — a genuinely common point of house variation worth an explicit toggle rather than a hardcoded assumption.

**Deliberately out of scope for a simple toggle**: 3-player and 4-player-partnership cribbage are structurally different games (different deal counts, an extra "kitty" card burned to the crib in 3-player, partnership scoring in 4-player) — not just a scoring-threshold change. If you want these later, treat that as its own scoping conversation rather than something that silently falls out of `Ruleset`, since it touches dealing and crib-building logic, not just scoring.

## State & Sync

Event-sourced reducer from day one, even for solo play — this single choice is what avoids separate solo/Multipeer/SharePlay implementations later:

```swift
struct GameState: Codable, Equatable { /* players, hands, crib, starter, pegging pile, scores, phase, seed */ }
enum Move: Codable { case discard(...), playCard(...), sayGo, revealStarter, ... }
enum GameEngine { static func reduce(_ state: GameState, applying move: Move) -> GameState }
```

Solo play calls `reduce` directly. Multipeer and SharePlay both apply local moves optimistically through `reduce` *and* send them over a `GameTransport` protocol; incoming remote moves go through the identical `reduce`. Because both peers start from the same seeded `GameState` and apply the same ordered moves through the same pure function, states converge with no custom diffing. `MultipeerGameTransport` wraps `MCSession`/`MCNearbyServiceAdvertiser`/`MCNearbyServiceBrowser`; `GroupActivityGameTransport` wraps `GroupSessionMessenger` from the `GroupActivities` framework — same protocol, same reducer, no rearchitecture between the two. Building both as MVP means the transport abstraction gets validated by two real conformances early rather than just one, which is also a good correctness check on the abstraction itself.

## watchOS Companion

Thin companion to the phone, not standalone — the realistic scope for a first watchOS app. Source of truth (peg positions, match state) stays on the phone; the watch sends "increment this peg" intents and both sides sync via `WCSession.updateApplicationContext(_:)` (last-write-wins is fine for one person operating both devices at a live game). A fully phone-independent watch app is real but explicitly post-MVP.

## Vision Hand-Scanning

The correctly-flagged highest-risk item — no built-in playing-card detector exists, so a hybrid pipeline scoped for a newcomer:

1. `VNDetectRectanglesRequest` locates each card (no training needed — strong rectangular contrast against a table).
2. `CIPerspectiveCorrection` deskews using the detected corners.
3. Crop to the standard top-left corner pip.
4. **Rank** via `VNRecognizeTextRequest` (Vision's built-in OCR — ranks are real glyphs).
5. **Suit** via a small custom CoreML classifier — only 4 classes, trainable with Create ML's no-code Image Classifier template on a few hundred labeled corner crops.

This is deliberately smaller than a full 52-class card detector while still feeling magical. **Mandatory from day one of this feature**: an editable rank/suit picker pre-filled with each guess (low-confidence ones flagged), requiring explicit confirmation before the discard engine runs — a misread feeding "optimal" advice is worse than no advice. This confirmation UI doubles as the plain manual "tap to build your hand" entry screen needed early anyway for testing the engine without a camera.

## RNG & Fairness

`Array.shuffle(using:)` already implements sound Fisher-Yates; what needs building is a **seeded, deterministic `RandomNumberGenerator`** (e.g. xoshiro256**) so shuffles are reproducible — `SystemRandomNumberGenerator` is intentionally non-reproducible, which is wrong for replay. Each hand gets a fresh 256-bit seed from the OS CSPRNG, stored on `GameState`.

**Commit-then-reveal for Multipeer** (the meaningful part, not theater): before dealing, the dealing device sends `SHA256(seed)` via CryptoKit; only after the hand is scored does it reveal the actual seed, letting the other device verify the hash matches *and* independently re-derive the same deal. **Solo vs. CPU has no adversary**, so the same mechanism there is a transparency/replay feature, not a security proof — label it differently in-app ("Replay & Transparency" vs. "Fairness Proof") so users aren't misled, even though it's the same underlying code path. This seed is exactly what powers "practice this exact hand again" — replay isn't a separate mechanism, it's `ReplayEngine.replay(seed:)` reconstructing the same deal and re-running the same move log.

## Accessibility

Structural, not a modifier afterthought. Every card is a distinct accessibility element with real state (`"Five of Hearts, in your hand"` vs. `"played, count is twenty-three"`). Custom Accessibility Rotors ("Pegging Events," "Hand") let VoiceOver users jump between conceptual groups. Async events with no visual focus target (CPU's turn, opponent plays, a "go," points scored) need proactive announcements — centralize this as a pure `AnnouncementBuilder(previous:next:move:) -> [String]` in `CribbageKit` (testable, no framework dependency) paired with a thin `AccessibilityAnnouncer` in `CribbageUI` that actually posts them, so the four platforms' differences are absorbed in one place instead of scattered `UIAccessibility.post` calls. Schedule a real VoiceOver pass once the core loop works but before the app grows (Phase 5 below) — retrofitting later is real debt.

## Device Testing & App Store Logistics

Easy to discover too late, so calling it out now: **Multipeer, WatchConnectivity, SharePlay, and camera-based Vision scanning do not work in Simulator** — they need real hardware from early on, not just at the end. This means:

- An Apple Developer Program membership ($99/yr) is needed well before the Multipeer/Watch/SharePlay/Vision phases, not just before App Store submission — it's required to run on physical devices at all (free personal-team provisioning covers short-lived on-device runs, but TestFlight and multi-device testing need the paid program).
- SharePlay testing needs two real devices, signed into two different Apple IDs, on an actual FaceTime call — there's no meaningful simulator substitute for the full experience. Line up a second tester (whoever you'll actually play with) before this phase, not the week you start it.
- Vision hand-scanning requires a camera-usage privacy string (`NSCameraUsageDescription`) and, for current App Store requirements, a privacy manifest declaring camera use — budget time for this alongside the Vision phase itself, not as a submission-day surprise.
- TestFlight is how the "play with someone else" goal actually gets tested end-to-end (Multipeer pass-and-play and SharePlay both) — get a build onto a second person's device as soon as there's a playable core loop, rather than waiting until everything is finished.

## Visual Design & Assets

"Gorgeous" is a stated goal, and it's real work independent of the architecture above: card face artwork (SF Symbols won't cut it — either license a card asset set or design one, with dark-mode variants), an app icon, and a small consistent design system for the board/scoreboard UI, built on the Liquid Glass/Golden Gate conventions above (tighter corner radii matching current system chrome, colorized sidebar icons for iPad/Mac navigation, uniform toolbar treatment). Worth scoping as its own to-do alongside Phase 3 (once there's a UI worth making gorgeous) rather than assumed to fall out of the code architecture.

## Cross-Device History Sync

Since the app is explicitly multi-platform, **enable SwiftData's near-native CloudKit sync for `CribbageData`** (match history, drill stats, settings) from the start — game history recorded on iPhone should just show up on iPad/Mac automatically, with no separate sync mechanism to build. This is cheap to turn on while the schema is still simple (an iCloud container entitlement, CloudKit-compatible model constraints — all properties need defaults or be optional, no unique constraints) and meaningfully more work to retrofit once real data and a grown schema exist. Build this into `CribbageData` as of Phase 7 (physical board companion mode), since that's the first phase that introduces SwiftData at all — there's no separate later phase needed for this.

## Game Center

Achievements and leaderboards are a cheap, well-fitting addition, not an architectural one: they're just `GKAchievement`/`GKLeaderboard` reporting calls triggered at state transitions that already exist — a solo-game win/skunk in `GameSessionController`, a completed `BoardMatch` in the physical-board companion. Following the same pattern as `AccessibilityAnnouncer` (a thin platform-specific layer reacting to state changes, not a change to the pure engine), this can be a small `GameCenterReporter`-style addition in `CribbageUI` with no changes to `CribbageKit`/`CribbageBoardKit` at all.

Turn-based async matchmaking (playing a friend over days, not live) is a different and much bigger question, deliberately kept out of the MVP phases below: `GKTurnBasedMatch` is store-and-forward through Apple's servers, not a live session, so it doesn't fit the existing `GameTransport` protocol (built for Multipeer/SharePlay's live message-passing) — it would need its own transport shape entirely. That's real new scope, not a bolt-on, so it's listed under Post-MVP rather than folded into the current phases.

## Recommended Build Order

Sequenced so logic gets proven before UI complexity, cross-cutting concerns (RNG, accessibility) get established early, and every MVP feature you asked for still ends up shipped and working together:

0. **Learn cribbage; get comfortable in Xcode.** Play real hands until scoring feels intuitive — this is the part you can't outsource, since it's what lets you catch a wrong-feeling build later. In parallel, repoint `xcode-select` at the full Xcode install (see Prerequisite Tooling above — it's already installed, just not currently selected) and get comfortable enough to open a project, hit Run, and use the Simulator, since that's your loop for every phase from here on. Also enroll in the Apple Developer Program now (see Device Testing & Logistics) since later phases need real hardware, not just Simulator.
1. **Project scaffolding** — Claude installs the remaining Homebrew tooling (`xcodegen`, `swiftlint`), scaffolds the workspace and empty Swift packages described above via an `xcodegen` YAML spec, with a trivial `swift test` passing, so the shape of the project exists before real logic is written. Also initializes the git repo (see Repository Setup above), adds the `.gitignore`/`LICENSE`/`README`, pushes the initial scaffold to the public `FifteenTwo` GitHub repo, and checks whether Xcode's MCP server can be connected to this session (see Working Style above) since it changes the iteration loop for every phase after this one.
2. **`CribbageKit` core + `Scorer`, no UI** — exhaustively unit-test against reference hands (max 29-point hand, crib-flush edge case) and official ACC rules at the command line. Highest-leverage phase to get right.
3. **Solo game loop, naive CPU, bare iPhone UI** — wire `GameState`/`Move`/`GameEngine.reduce` end to end, plus the manual "tap to build a hand" entry UI (dual-purpose: also the later Vision-correction fallback). "Bare" here means built from standard SwiftUI system components (`NavigationStack`, system toolbars, standard controls) rather than custom-drawn chrome — functionally rough is fine, fighting the design system isn't, since standard components are what let Liquid Glass/Golden Gate styling apply for free later. **Milestone: first TestFlight build to your own devices** — a playable, if unpolished, full game is worth having in hand this early, both for motivation and as the first real test of the reducer.
4. **Solvers + training/replay + visual polish pass** — add `DiscardSolver`/`PeggingSolver` (with difficulty tiers), swap in the real CPU, build the EV-breakdown and replay screens, and invest in the "gorgeous" pass (Design Language + Visual Design & Assets above: card artwork, `.glassEffect`/`GlassEffectContainer` adoption on the score HUD and toolbars, app icon) — the primary iPhone experience is feature-complete enough at this point to be worth making delightful before layering on more platforms.
5. **RNG fairness UI** — surface the seed-reveal/replay screen with mode-correct copy.
6. **Accessibility pass** — VoiceOver announcements, rotors, custom actions for everything built so far.
7. **Physical board companion mode** — its own lightweight module, first use of SwiftData for match history, with CloudKit sync (see Cross-Device History Sync above) enabled from this first use rather than bolted on later. Good second feature: simpler than the full engine, momentum builder.
8. **watchOS companion for board mode** — `WCSession.updateApplicationContext`, thin companion only.
9. **iPad + Mac polish** — adaptive layouts (`NavigationSplitView`, Mac windowing/pointer support), mechanical work sequenced after logic is proven.
10. **Game Center achievements & leaderboards** — see Game Center above. A thin `CribbageUI` reporter reacting to existing game-over/match-completion events; ready to build now that both solo wins (Phase 4) and board-match completion (Phase 7) exist, and low-risk enough to slot in once the core cross-platform experience is solid.
11. **Multipeer pass-and-play** — `CribbageSync` + `MultipeerGameTransport`, now that `reduce` is battle-tested solo.
12. **SharePlay** — `GroupActivityGameTransport` (`GroupActivities`/`GroupSessionMessenger`) as the second `GameTransport` conformance, plus the `GroupActivity` registration and FaceTime-launch UI. Sequenced right after Multipeer on purpose: the transport abstraction and reducer are proven by then, so this phase's genuinely new work is scoped to GroupActivities-specific plumbing and UI, not game logic. Line up a second tester ahead of this phase (see Device Testing & Logistics).
13. **Vision hand-scanning** — last among MVP features on purpose: rectangle detection + OCR + suit classifier + mandatory manual-confirmation, reusing the Phase 3 entry UI.
14. **Post-MVP**: Widgets/Live Activities — set up the App Group container convention *before* any widget exists so SwiftData already lives in the shared container (retrofitting later needs a data migration); Game Center turn-based async matchmaking — see Game Center above for why this needs its own transport shape rather than reusing `GameTransport`, which is why it's here rather than alongside Multipeer/SharePlay.

## Critical Files

- `Packages/CribbageKit/Sources/CribbageKit/Scoring/Scorer.swift`
- `Packages/CribbageKit/Sources/CribbageKit/Solvers/DiscardSolver.swift`
- `Packages/CribbageKit/Sources/CribbageKit/Solvers/PeggingSolver.swift`
- `Packages/CribbageKit/Sources/CribbageKit/GameState/GameEngine.swift`
- `Packages/CribbageKit/Sources/CribbageKit/RNG/SeededGenerator.swift`
- `Packages/CribbageSync/Sources/CribbageSync/GameTransport.swift`
- `Packages/CribbageSync/Sources/CribbageSync/GroupActivityGameTransport.swift`
- `Packages/CribbageBoardKit/Sources/CribbageBoardKit/BoardMatch.swift`

## Verification

- **Engine correctness**: `swift test` on `CribbageKit` against known reference hands (29-point max hand, crib-flush edge cases, skunk/double-skunk thresholds), each traceable to the official ACC rules text or a published reference-hand source — not an assumed/guessed expected value — before any UI exists.
- **Solver sanity**: spot-check `DiscardSolver` output against published optimal-discard tables for a handful of well-known hands.
- **Two-device Multipeer test**: run the app on two physical devices (simulator can't do Multipeer/Bluetooth) side by side, play a full hand, confirm state converges and the commit-reveal hash checks out.
- **VoiceOver pass**: enable VoiceOver in Settings and play a full hand eyes-free after Phase 6, confirming every card, score change, and CPU turn is announced.
- **Vision pipeline**: test the rectangle-detect → perspective-correct → OCR/suit-classify path against real dealt hands in varied lighting, confirming the manual-correction screen catches misreads before EV analysis runs.
