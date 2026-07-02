import Testing
@testable import WendyKMSBackend

@MainActor
private func makeTree() -> (root: KMSWidget, button: KMSWidget, fired: () -> Int) {
    var count = 0
    let root = KMSWidget(.container)
    root.size = SIMD2(800, 600)
    let btn = KMSWidget(.button)
    btn.size = SIMD2(100, 40)
    btn.action = { count += 1 }
    root.children.append((btn, SIMD2(100, 100)))   // frame: 100..199 x 100..139
    return (root, btn, { count })
}

@MainActor
@Test func tapOnButtonFiresActionAndTogglesPressed() {
    let b = WendyKMSBackend()
    let (root, btn, fired) = makeTree()
    b.handleTouch(.down(SIMD2(150, 120)), root: root)
    #expect(btn.pressed)
    b.handleTouch(.up(SIMD2(152, 121)), root: root)
    #expect(!btn.pressed)
    #expect(fired() == 1)
}

@MainActor
@Test func dragOffBeyondSlopCancels() {
    let b = WendyKMSBackend()
    let (root, btn, fired) = makeTree()
    b.handleTouch(.down(SIMD2(150, 120)), root: root)
    b.handleTouch(.move(SIMD2(400, 120)), root: root)
    b.handleTouch(.up(SIMD2(400, 120)), root: root)
    #expect(fired() == 0)
    #expect(!btn.pressed)   // pressed cleared on up even without a tap
}

@MainActor
@Test func tapOnEmptySpaceFiresNothing() {
    let b = WendyKMSBackend()
    let (root, _, fired) = makeTree()
    b.handleTouch(.down(SIMD2(500, 500)), root: root)
    b.handleTouch(.up(SIMD2(500, 500)), root: root)
    #expect(fired() == 0)
}

@Test func orientationMapsSwapAndInversion() {
    // 800x600 display. Identity: (0.25, 0.5) → (200, 300).
    let identity = TouchOrientation(swapXY: false, invertX: false, invertY: false)
    #expect(identity.pixelPoint(nx: 0.25, ny: 0.5, width: 800, height: 600) == SIMD2(200, 300))
    // Swap: normalized axes exchanged before scaling.
    let swapped = TouchOrientation(swapXY: true, invertX: false, invertY: false)
    #expect(swapped.pixelPoint(nx: 0.25, ny: 0.5, width: 800, height: 600) == SIMD2(400, 150))
    // Inversion mirrors within [0,1].
    let inverted = TouchOrientation(swapXY: false, invertX: true, invertY: true)
    #expect(inverted.pixelPoint(nx: 0.25, ny: 0.5, width: 800, height: 600) == SIMD2(600, 300))
}
