import Foundation
import Observation
import CribbageKit

/// Persisted app-wide settings: the house `Ruleset` for solo play, and Beginner Mode (see
/// docs/plan.md's House Rules section — `Ruleset` is "the only seam where variation is
/// allowed," this is just the UI that finally exposes it). A plain `UserDefaults`-backed
/// store, not SwiftData — this is small, singleton, device-local preference data, not
/// records worth a model/history.
@Observable
@MainActor
public final class SettingsStore {
    private enum Keys {
        static let ruleset = "SettingsStore.ruleset"
        static let beginnerMode = "SettingsStore.beginnerModeEnabled"
    }

    public var ruleset: Ruleset {
        didSet { persistRuleset() }
    }

    /// Shows itemized scoring breakdowns and contextual strategy tips throughout solo
    /// play — see the project's framing: "really lean into the training portion."
    public var beginnerModeEnabled: Bool {
        didSet { UserDefaults.standard.set(beginnerModeEnabled, forKey: Keys.beginnerMode) }
    }

    public init() {
        if let data = UserDefaults.standard.data(forKey: Keys.ruleset),
           let decoded = try? JSONDecoder().decode(Ruleset.self, from: data) {
            ruleset = decoded
        } else {
            ruleset = .standard
        }
        beginnerModeEnabled = UserDefaults.standard.bool(forKey: Keys.beginnerMode)
    }

    private func persistRuleset() {
        guard let data = try? JSONEncoder().encode(ruleset) else { return }
        UserDefaults.standard.set(data, forKey: Keys.ruleset)
    }
}
