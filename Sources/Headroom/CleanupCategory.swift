import Foundation

/// A cleanup target: a set of directories whose top-level contents can be safely removed.
struct CleanupCategory: Identifiable, Sendable {
    let id: String
    let name: String
    let detail: String
    let symbolName: String
    let directories: [URL]

    static func allCategories() -> [CleanupCategory] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var categories: [CleanupCategory] = []

        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            categories.append(CleanupCategory(
                id: "caches",
                name: "App Caches",
                detail: "Cached data apps rebuild automatically",
                symbolName: "shippingbox",
                directories: [caches]
            ))
        }

        categories.append(CleanupCategory(
            id: "temp",
            name: "Temporary Files",
            detail: "Your user temporary directory",
            symbolName: "clock.arrow.circlepath",
            directories: [URL(fileURLWithPath: NSTemporaryDirectory())]
        ))

        categories.append(CleanupCategory(
            id: "logs",
            name: "Log Files",
            detail: "Diagnostic logs in ~/Library/Logs",
            symbolName: "doc.text.magnifyingglass",
            directories: [home.appendingPathComponent("Library/Logs")]
        ))

        if let trash = fm.urls(for: .trashDirectory, in: .userDomainMask).first {
            categories.append(CleanupCategory(
                id: "trash",
                name: "Trash",
                detail: "Files waiting to be permanently deleted",
                symbolName: "trash",
                directories: [trash]
            ))
        }

        let derivedData = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        if fm.fileExists(atPath: derivedData.path) {
            categories.append(CleanupCategory(
                id: "deriveddata",
                name: "Xcode Derived Data",
                detail: "Build products Xcode regenerates on demand",
                symbolName: "hammer",
                directories: [derivedData]
            ))
        }

        return categories
    }
}

/// Result of scanning one category.
struct ScanResult: Sendable {
    var totalBytes: Int64 = 0
    var itemCount: Int = 0
}
