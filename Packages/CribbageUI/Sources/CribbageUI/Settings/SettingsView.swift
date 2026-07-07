#if !os(watchOS)
import SwiftUI
import CribbageKit

/// House rules and Beginner Mode — see docs/plan.md's House Rules section: `Ruleset` is
/// the model, this is finally the UI for it. Changes to solo play's ruleset apply to the
/// next game, not retroactively to one in progress (see `GameSessionController.ruleset`'s
/// doc comment).
public struct SettingsView: View {
    @Bindable var settings: SettingsStore

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Beginner Mode", isOn: $settings.beginnerModeEnabled)
                } footer: {
                    Text(
                        "Shows a detailed breakdown of every score and strategy tips while you play in " +
                            "Solo mode — great for learning the game."
                    )
                }

                Section {
                    Picker("Game Length", selection: $settings.ruleset.gameTarget) {
                        Text("Short Game (61)").tag(61)
                        Text("Standard (121)").tag(121)
                    }
                    Stepper(
                        "Skunk Threshold: \(settings.ruleset.skunkThreshold)",
                        value: $settings.ruleset.skunkThreshold, in: 1...120
                    )
                    Stepper(
                        "Double Skunk Threshold: \(settings.ruleset.doubleSkunkThreshold)",
                        value: $settings.ruleset.doubleSkunkThreshold, in: 1...120
                    )
                    Toggle("Muggins", isOn: $settings.ruleset.mugginsEnabled)
                    Toggle("Exactly 31 Scores 2 Points", isOn: $settings.ruleset.exactThirtyOneScoresTwo)
                } header: {
                    Text("House Rules (Solo Play)")
                } footer: {
                    Text(
                        "Muggins lets the app claim any points you missed. Some house rules score \"the go\" " +
                            "as 1 point even when the count reaches exactly 31 instead of 2 — " +
                            "turn this off to match that."
                    )
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(settings: SettingsStore())
}
#endif
