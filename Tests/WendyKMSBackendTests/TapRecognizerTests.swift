import Testing
@testable import WendyKMSBackend

@Test func upWithinSlopIsATapAtTheDownPoint() {
    var r = TapRecognizer(slop: 24)
    #expect(r.handle(.down(SIMD2(100, 100))) == nil)
    #expect(r.handle(.move(SIMD2(110, 105))) == nil)
    #expect(r.handle(.up(SIMD2(112, 106))) == SIMD2(100, 100))
}

@Test func movementBeyondSlopCancelsTheTap() {
    var r = TapRecognizer(slop: 24)
    _ = r.handle(.down(SIMD2(100, 100)))
    _ = r.handle(.move(SIMD2(200, 100)))   // > 24 px away
    #expect(r.handle(.up(SIMD2(100, 100))) == nil)  // returning doesn't un-cancel
}

@Test func upFarFromDownIsNotATap() {
    var r = TapRecognizer(slop: 24)
    _ = r.handle(.down(SIMD2(0, 0)))
    #expect(r.handle(.up(SIMD2(50, 0))) == nil)
}

@Test func upWithoutDownIsIgnored() {
    var r = TapRecognizer(slop: 24)
    #expect(r.handle(.up(SIMD2(10, 10))) == nil)
}

@Test func recognizerResetsAfterUp() {
    var r = TapRecognizer(slop: 24)
    _ = r.handle(.down(SIMD2(0, 0)))
    _ = r.handle(.up(SIMD2(0, 0)))          // tap 1
    #expect(r.handle(.up(SIMD2(0, 0))) == nil)  // stale up: no down since
    _ = r.handle(.down(SIMD2(5, 5)))
    #expect(r.handle(.up(SIMD2(5, 5))) == SIMD2(5, 5))  // tap 2 works
}
