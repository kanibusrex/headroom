import SwiftUI

@main
struct HeadroomApp: App {
    init() {
        // Running as a bare SPM executable: promote to a regular app so the
        // window gets a Dock icon and keyboard focus.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Headroom") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
