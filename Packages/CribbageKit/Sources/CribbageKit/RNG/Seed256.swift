import CryptoKit
import Foundation

/// A 256-bit seed for a single hand's shuffle — see docs/plan.md ("RNG & Fairness").
/// Freshly drawn from the OS CSPRNG per hand, carried on the `.dealHand` move (not
/// generated inside `GameEngine.reduce`, which must stay a pure function of its inputs
/// so Multipeer/SharePlay peers replaying the same move stream deal identically), and
/// stored on `RoundSummary` so a completed hand's deal can be reproduced afterward —
/// which is exactly what "practice this exact hand again" is: replaying the same seed.
public struct Seed256: Codable, Equatable, Hashable, Sendable {
    public let a: UInt64
    public let b: UInt64
    public let c: UInt64
    public let d: UInt64

    public init(a: UInt64, b: UInt64, c: UInt64, d: UInt64) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
    }

    public static func random() -> Seed256 {
        var rng = SystemRandomNumberGenerator()
        return Seed256(a: rng.next(), b: rng.next(), c: rng.next(), d: rng.next())
    }

    /// A short, human-showable form of the seed itself — this is the "Replay &
    /// Transparency" reveal, not a secret.
    public var hexString: String {
        [a, b, c, d].map { String(format: "%016llx", $0) }.joined()
    }

    /// SHA-256 of the seed bytes. Meaningful use (per docs/plan.md): in a future
    /// Multipeer game, the dealer sends only this hash *before* dealing, then reveals
    /// the seed after scoring — the peer verifies the hash matches and independently
    /// re-derives the same deal, proving it wasn't altered after the fact. In solo play
    /// there's no adversary, so showing this is transparency, not a security proof.
    public var commitHash: String {
        let bytes = [a, b, c, d].flatMap { value in (0..<8).map { UInt8((value >> (8 * (7 - $0))) & 0xFF) } }
        let digest = SHA256.hash(data: Data(bytes))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
