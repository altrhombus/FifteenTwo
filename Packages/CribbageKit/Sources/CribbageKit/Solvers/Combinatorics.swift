/// Every index-combination of size `k` from `0..<n`, smallest first. Used by the solvers
/// to enumerate discard/opponent-discard possibilities exactly (see docs/plan.md, "Discard
/// solver — confirmed exact and real-time").
func combinationIndices(_ n: Int, choose k: Int) -> [[Int]] {
    guard k > 0, k <= n else { return k == 0 ? [[]] : [] }

    var result: [[Int]] = []
    var combo: [Int] = []

    func build(_ start: Int) {
        if combo.count == k {
            result.append(combo)
            return
        }
        guard start < n else { return }
        for i in start..<n {
            combo.append(i)
            build(i + 1)
            combo.removeLast()
        }
    }

    build(0)
    return result
}
