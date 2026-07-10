import Foundation

struct InstalledApp: Identifiable, Sendable {
    let url: URL
    let name: String
    let bundleID: String?
    var size: Int64?

    var id: String { url.path }
}

struct LeftoverItem: Identifiable, Sendable {
    let url: URL
    let size: Int64

    var id: String { url.path }
}

/// Lists user-installed apps and finds the support files they leave behind.
/// Apple's own apps are excluded — they're system-managed and protected.
enum AppUninstaller {

    static func installedApps() -> [InstalledApp] {
        let fm = FileManager.default
        let dirs = [
            URL(fileURLWithPath: "/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var apps: [InstalledApp] = []
        for dir in dirs {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries where entry.pathExtension == "app" {
                let bundleID = Bundle(url: entry)?.bundleIdentifier
                if let id = bundleID, id.hasPrefix("com.apple.") { continue }
                apps.append(InstalledApp(
                    url: entry,
                    name: entry.deletingPathExtension().lastPathComponent,
                    bundleID: bundleID
                ))
            }
        }
        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Support files an app leaves in ~/Library, matched by bundle ID and app name.
    static func leftovers(for app: InstalledApp) -> [LeftoverItem] {
        let fm = FileManager.default
        let library = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library")

        var seen = Set<String>()
        var found: [URL] = []
        func check(_ relativePath: String) {
            let url = library.appendingPathComponent(relativePath)
            guard fm.fileExists(atPath: url.path), seen.insert(url.path).inserted else { return }
            found.append(url)
        }

        if let id = app.bundleID {
            check("Application Support/\(id)")
            check("Caches/\(id)")
            check("Preferences/\(id).plist")
            check("Logs/\(id)")
            check("Containers/\(id)")
            check("Saved Application State/\(id).savedState")
            check("HTTPStorages/\(id)")
            check("WebKit/\(id)")
        }
        check("Application Support/\(app.name)")
        check("Caches/\(app.name)")
        check("Logs/\(app.name)")

        return found.map { LeftoverItem(url: $0, size: CleanerEngine.allocatedSize(of: $0)) }
    }

    static func moveToTrash(_ urls: [URL]) -> (freed: Int64, errors: [String]) {
        LargeFileScanner.moveToTrash(urls)
    }
}
