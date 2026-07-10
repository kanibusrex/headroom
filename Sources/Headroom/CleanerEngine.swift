import Foundation

/// Scans and cleans cleanup categories. All work happens off the main thread.
enum CleanerEngine {

    /// Total size and item count of the top-level entries in the category's directories.
    static func scan(_ category: CleanupCategory) -> ScanResult {
        let fm = FileManager.default
        var result = ScanResult()

        for directory in category.directories {
            guard let entries = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            result.itemCount += entries.count
            for entry in entries {
                result.totalBytes += allocatedSize(of: entry)
            }
        }
        return result
    }

    /// Removes the top-level entries of each directory (never the directory itself).
    /// Returns the number of bytes actually freed. Entries that can't be removed
    /// (e.g. in use or permission-protected) are skipped.
    static func clean(_ category: CleanupCategory) -> Int64 {
        let fm = FileManager.default
        var freed: Int64 = 0

        for directory in category.directories {
            guard let entries = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                let size = allocatedSize(of: entry)
                do {
                    try fm.removeItem(at: entry)
                    freed += size
                } catch {
                    continue
                }
            }
        }
        return freed
    }

    /// Recursive on-disk (allocated) size of a file or directory.
    static func allocatedSize(of url: URL) -> Int64 {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .totalFileAllocatedSizeKey]

        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }

        var total = Int64(values.totalFileAllocatedSize ?? 0)

        if values.isDirectory == true {
            let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
                options: [],
                errorHandler: { _, _ in true }
            )
            while let child = enumerator?.nextObject() as? URL {
                if let childValues = try? child.resourceValues(forKeys: [.totalFileAllocatedSizeKey]) {
                    total += Int64(childValues.totalFileAllocatedSize ?? 0)
                }
            }
        }
        return total
    }

    /// Free and total capacity of the volume containing the user's home directory.
    static func diskSpace() -> (free: Int64, total: Int64)? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let values = try? home.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]),
        let free = values.volumeAvailableCapacityForImportantUsage,
        let total = values.volumeTotalCapacity else { return nil }
        return (Int64(free), Int64(total))
    }
}
