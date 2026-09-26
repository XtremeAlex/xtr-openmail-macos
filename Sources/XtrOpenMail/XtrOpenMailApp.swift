import SwiftUI

@main
struct XtrOpenMailApp: App {
    var body: some Scene {
        WindowGroup("xtr-openmail-macos") {
            ContentView()
                .frame(minWidth: 720, minHeight: 480)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
