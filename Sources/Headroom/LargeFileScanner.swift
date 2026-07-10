import Foundation

struct LargeFile: Identifiable, Sendable {
    let url: URL
    let size: Int64
    let modified: Date?

    var id: String { url.path }
}

/// Finds the largest files in the user's home folder, skipping ~/Library,
/// hidden files, and the insides of app/package bundles.
enum LargeFileScanner {

    static func scan(minBytes: Int64, limit: Int = 200) -> [LargeFile] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .totalFileAllocatedSizeKey, .contentModificationDateKey
        ]

        guard let enumerator = fm.enumerator(
            at: home,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var results: [LargeFile] = []
        while let url = enumerator.nextObject() as? URL {
            if enumerator.level == 1 && url.lastPathComponent == "Library" {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.totalFileAllocatedSize,
                  Int64(size) >= minBytes else { continue }

            results.append(LargeFile(
                url: url,
                size: Int64(size),
                modified: values.contentModificationDate
            ))
        }

        return Array(results.sorted { $0.size > $1.size }.prefix(limit))
    }

    /// Moves files to the Trash. Returns bytes freed and any per-file errors.
    static func moveToTrash(_ urls: [URL]) -> (freed: Int64, errors: [String]) {
        var freed: Int64 = 0
        var errors: [String] = []
        for url in urls {
            let size = CleanerEngine.allocatedSize(of: url)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                freed += size
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return (freed, errors)
    }
}
