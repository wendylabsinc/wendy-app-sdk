import Testing
import WendyKMSInput
@testable import WendyKMSBackend

// On macOS the shim is a stub: open fails gracefully with a diagnostic and
// never crashes. (The Linux path is exercised by hardware acceptance.)
@Test func inputOpenFailsGracefullyOffLinux() {
    var device = WendyInputDevice()
    var err = [CChar](repeating: 0, count: 256)
    let rc = wendy_input_open(&device, &err, 256)
    #if !os(Linux)
    #expect(rc != 0)
    #expect(wendy_input_fd(&device) == -1)
    let msg = String(cString: err)
    #expect(!msg.isEmpty)
    #endif
    wendy_input_close(&device)
    #expect(wendy_input_fd(&device) == -1)
}
