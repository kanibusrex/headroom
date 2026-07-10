import AppKit
import SwiftUI

/// Dev tool: `Headroom --screenshot <dir> <tab>` renders one tab to a PNG
/// (used to generate the README screenshots) and exits. One tab per process:
/// after the first ImageRenderer pass, later renders in the same process come
/// out dimmed, as if drawn in an inactive window.
@MainActor
enum Screenshotter {

    static func run(outputDirectory: String, tab: String) {
        let dir = URL(fileURLWithPath: outputDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let cleaner = CleanerViewModel()
        let largeFiles = LargeFilesViewModel()
        let uninstaller = UninstallerViewModel()
        let tool: Tool

        switch tab {
        case "cleanup":
            tool = .cleanup
            for index in cleaner.categories.indices {
                cleaner.categories[index].result = CleanerEngine.scan(cleaner.categories[index].category)
                cleaner.categories[index].isScanning = false
            }
            cleaner.hasScanned = true

        case "large-files":
            tool = .largeFiles
            largeFiles.files = Array(LargeFileScanner.scan(minBytes: 100_000_000).prefix(8))
            largeFiles.hasScanned = true
            for file in largeFiles.files.prefix(2) {
                largeFiles.selection.insert(file.id)
            }

        case "uninstaller":
            tool = .uninstaller
            var apps = Array(AppUninstaller.installedApps().prefix(9))
            let urls = apps.map(\.url)
            var sizes = [Int64](repeating: 0, count: urls.count)
            sizes.withUnsafeMutableBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                DispatchQueue.concurrentPerform(iterations: urls.count) { index in
                    base[index] = CleanerEngine.allocatedSize(of: urls[index])
                }
            }
            for (index, size) in sizes.enumerated() {
                apps[index].size = size
            }
            uninstaller.apps = apps
            uninstaller.hasLoaded = true
            IconStore.preloadAppIcons(appURLs: urls)

        default:
            print("Unknown tab \(tab); expected cleanup, large-files, or uninstaller")
            return
        }

        snapshot(
            tool: tool, name: tab, to: dir,
            cleaner: cleaner, largeFiles: largeFiles, uninstaller: uninstaller
        )
    }

    private static func snapshot(
        tool: Tool,
        name: String,
        to dir: URL,
        cleaner: CleanerViewModel,
        largeFiles: LargeFilesViewModel,
        uninstaller: UninstallerViewModel
    ) {
        let view = ContentView(
            initialTool: tool,
            cleaner: cleaner,
            largeFiles: largeFiles,
            uninstaller: uninstaller
        )
        .frame(width: 1040, height: 700)
        .environment(\.colorScheme, .dark)
        .environment(\.controlActiveState, .key)
        .environment(\.screenshotMode, true)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("Failed to render \(name)")
            return
        }
        let url = dir.appendingPathComponent("\(name).png")
        do {
            try png.write(to: url)
            print("Wrote \(url.path)")
        } catch {
            print("Failed to write \(name): \(error.localizedDescription)")
        }
    }
}
