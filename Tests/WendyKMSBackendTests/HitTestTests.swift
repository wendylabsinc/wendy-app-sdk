import Testing
@testable import WendyKMSBackend

private func button(_ size: SIMD2<Int>) -> KMSWidget {
    let w = KMSWidget(.button)
    w.size = size
    w.action = {}
    return w
}

@Test func hitFindsButtonThroughNestedOffsets() {
    let root = KMSWidget(.container)
    root.size = SIMD2(800, 600)
    let panel = KMSWidget(.container)
    panel.size = SIMD2(400, 300)
    let btn = button(SIMD2(100, 40))
    panel.children.append((btn, SIMD2(50, 60)))
    root.children.append((panel, SIMD2(200, 100)))
    // btn's absolute frame: x 250..349, y 160..199
    #expect(KMSHitTest.actionTarget(in: root, at: SIMD2(260, 170)) === btn)
    #expect(KMSHitTest.actionTarget(in: root, at: SIMD2(249, 170)) == nil)
    #expect(KMSHitTest.actionTarget(in: root, at: SIMD2(260, 200)) == nil)
}

@Test func widgetsWithoutActionsAreTransparent() {
    let root = KMSWidget(.container)
    root.size = SIMD2(100, 100)          // sized, but no action
    let rect = KMSWidget(.colorRect)
    rect.size = SIMD2(100, 100)
    root.children.append((rect, .zero))
    #expect(KMSHitTest.actionTarget(in: root, at: SIMD2(10, 10)) == nil)
}

@Test func deepestActionWinsOverAncestorAction() {
    let outer = button(SIMD2(200, 200))
    let inner = button(SIMD2(50, 50))
    outer.children.append((inner, SIMD2(10, 10)))
    #expect(KMSHitTest.actionTarget(in: outer, at: SIMD2(20, 20)) === inner)
    #expect(KMSHitTest.actionTarget(in: outer, at: SIMD2(150, 150)) === outer)
}

@Test func laterSiblingPaintedOnTopWinsTies() {
    let root = KMSWidget(.container)
    root.size = SIMD2(200, 200)
    let below = button(SIMD2(100, 100))
    let above = button(SIMD2(100, 100))
    root.children.append((below, .zero))
    root.children.append((above, SIMD2(50, 50)))   // overlaps below in 50..99
    #expect(KMSHitTest.actionTarget(in: root, at: SIMD2(75, 75)) === above)
    #expect(KMSHitTest.actionTarget(in: root, at: SIMD2(25, 25)) === below)
}
