/// xoshiro256** (Blackman & Vigna, public domain) — a well-vetted generator seeded from
/// a full 256-bit `Seed256`, used specifically for the deck shuffle so a hand's deal is
/// both high-quality random and exactly reproducible from its seed. `SeededGenerator`
/// (SplitMix64) remains what the CPU uses for its own move-sampling randomness, which
/// has no fairness/replay requirement — this is deliberately a separate, smaller-scope
/// generator rather than a change to that one.
public struct Xoshiro256StarStar: RandomNumberGenerator, Sendable {
    private var state: (UInt64, UInt64, UInt64, UInt64)

    public init(seed: Seed256) {
        if seed.a == 0 && seed.b == 0 && seed.c == 0 && seed.d == 0 {
            // xoshiro requires non-zero state; astronomically unlikely from a real
            // CSPRNG draw, but defend against it rather than silently producing zeros.
            state = (1, 1, 1, 1)
        } else {
            state = (seed.a, seed.b, seed.c, seed.d)
        }
    }

    private static func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 {
        (x << k) | (x >> (64 - k))
    }

    public mutating func next() -> UInt64 {
        let result = Self.rotl(state.1 &* 5, 7) &* 9
        let t = state.1 << 17

        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3
        state.2 ^= t
        state.3 = Self.rotl(state.3, 45)

        return result
    }
}
