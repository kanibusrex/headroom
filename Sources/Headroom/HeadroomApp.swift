import SwiftUI

@main
struct HeadroomApp: App {
    init() {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--screenshot"), arguments.count > index + 2 {
            Screenshotter.run(outputDirectory: arguments[index + 1], tab: arguments[index + 2])
            exit(0)
        }

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
