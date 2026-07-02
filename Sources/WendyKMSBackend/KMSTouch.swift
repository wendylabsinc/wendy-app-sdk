/// Touch events in display-pixel space (after normalization + orientation).
enum TouchEvent: Equatable {
    case down(SIMD2<Int>)
    case move(SIMD2<Int>)
    case up(SIMD2<Int>)
}

/// Recognizes taps: an `up` whose entire contact stayed within `slop` px of its
/// `down`. `handle` returns the down-point when a tap completes, else nil.
/// Value type; no timing component (long-press is out of scope).
struct TapRecognizer {
    let slop: Int
    private var downPoint: SIMD2<Int>?
    private var cancelled = false

    init(slop: Int) { self.slop = slop }

    mutating func handle(_ event: TouchEvent) -> SIMD2<Int>? {
        switch event {
        case .down(let p):
            downPoint = p
            cancelled = false
            return nil
        case .move(let p):
            if let d = downPoint, !cancelled, exceedsSlop(p, d) { cancelled = true }
            return nil
        case .up(let p):
            defer { downPoint = nil }
            guard let d = downPoint, !cancelled, !exceedsSlop(p, d) else { return nil }
            return d
        }
    }

    private func exceedsSlop(_ a: SIMD2<Int>, _ b: SIMD2<Int>) -> Bool {
        let dx = a.x - b.x, dy = a.y - b.y
        return dx * dx + dy * dy > slop * slop
    }
}
