import Testing
@testable import WendyKMSBackend

@MainActor
@Test func containerInsertAndPosition() {
    let b = WendyKMSBackend()
    let container = b.createContainer()
    let child = b.createContainer()
    b.insert(child, into: container, at: 0)
    #expect(container.children.count == 1)
    b.setPosition(ofChildAt: 0, in: container, to: SIMD2(7, 9))
    #expect(container.children[0].position == SIMD2(7, 9))
    b.remove(childAt: 0, from: container)
    #expect(container.children.isEmpty)
}

@MainActor
@Test func setSizeAndNaturalSize() {
    let b = WendyKMSBackend()
    let w = b.createContainer()
    b.setSize(of: w, to: SIMD2(40, 20))
    #expect(b.naturalSize(of: w) == .zero)        // containers size from children
    #expect(w.size == SIMD2(40, 20))
}
