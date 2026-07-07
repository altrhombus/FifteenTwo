#if !os(watchOS)
import SwiftUI
import CribbageKit

/// Solo play has no adversary, so this is framed as transparency/replay, not a fairness
/// *proof* — see docs/plan.md ("RNG & Fairness"): the same seed-reveal mechanism means
/// something stronger once Multipeer exists (Phase 10), where the copy changes to match.
struct ReplayTransparencyView: View {
    let seed: Seed256
    let onPracticeAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Replay & Transparency").font(.headline)
            Text("This hand's deal was determined by a seed generated before dealing:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(seed.hexString.prefix(16) + "…")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Button("Practice This Hand Again") {
                onPracticeAgain()
            }
            .buttonStyle(.bordered)
        }
    }
}

/// The post-hand training breakdown: how the human's discard compares to every option
/// `DiscardSolver` considered — see docs/plan.md ("post-game breakdown showing expected
/// value of every discard choice you could've made").
struct DiscardAnalysisView: View {
    let analysis: DiscardAnalysis

    var body: some View {
        if let chosen = analysis.chosenOption, let best = analysis.bestOption {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Discard").font(.headline)
                row(label: "You discarded", option: chosen)

                if Set(chosen.discarded) == Set(best.discarded) {
                    Text("That was the best possible discard!")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    row(label: "Best discard", option: best)
                    let delta = best.netExpectedValue - chosen.netExpectedValue
                    Text("You left \(delta, specifier: "%.1f") expected points on the table.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func row(label: String, option: DiscardOption) -> some View {
        HStack {
            Text("\(label): \(option.discarded.map { "\($0.rank.symbol)\($0.suit.symbol)" }.joined(separator: " "))")
            Spacer()
            Text("\(option.netExpectedValue, specifier: "%.1f") pts")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}
#endif
