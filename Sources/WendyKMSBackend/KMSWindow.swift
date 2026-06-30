import WendyKMSDRM
import WendyTextKit

public final class KMSWindow {
    var display = WendyKMSDisplay()
    var root: KMSWidget?
    var dirty = true
    let font = FontFace.bundled()
    var isOpen = false

    init() {}
}
