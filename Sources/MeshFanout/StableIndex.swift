/// Deterministically maps `id` to an index in `0..<paletteSize` — the same
/// `id` always yields the same index within one process, which is all a
/// demo "pick this device's color" needs. Uses Swift's built-in `Hasher`
/// rather than a hand-rolled hash; the result is stable for the lifetime of
/// one run but NOT guaranteed stable across processes (`Hasher` is seeded
/// randomly per process) — fine here, since each device only ever needs its
/// OWN index to stay the same for the duration of one demo session, not to
/// match some fixed external scheme shared with other devices.
public func stablePaletteIndex(for id: String, paletteSize: Int) -> Int {
    guard paletteSize > 0 else { return 0 }
    var hasher = Hasher()
    hasher.combine(id)
    let hash = hasher.finalize()
    return Int(UInt(bitPattern: hash) % UInt(paletteSize))
}
