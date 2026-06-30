import WendyUI
import Foundation

@main
struct TickDemo: App {
    @State var count = 0

    var body: some Scene {
        WindowGroup("TickDemo") {
            VStack {
                Text("WendyKMSBackend tick demo")
                Text("count: \(count)")
            }
            .padding(40)
            .task {
                while true {
                    try? await Task.sleep(for: .seconds(1))
                    count += 1
                }
            }
        }
    }
}
