import Foundation
import SwiftUI

@MainActor
final class CleanerViewModel: ObservableObject {

    struct CategoryState: Identifiable {
        let category: CleanupCategory
        var isSelected = true
        var isScanning = false
        var result: ScanResult?

        var id: String { category.id }
    }

    @Published var categories: [CategoryState]
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var hasScanned = false
    @Published var lastFreedBytes: Int64?
    @Published var diskFree: Int64 = 0
    @Published var diskTotal: Int64 = 0

    init() {
        categories = CleanupCategory.allCategories().map { CategoryState(category: $0) }
        refreshDiskSpace()
    }

    var selectedBytes: Int64 {
        categories
            .filter { $0.isSelected }
            .compactMap { $0.result?.totalBytes }
            .reduce(0, +)
    }

    var canClean: Bool {
        hasScanned && !isScanning && !isCleaning && selectedBytes > 0
    }

    func refreshDiskSpace() {
        if let space = CleanerEngine.diskSpace() {
            diskFree = space.free
            diskTotal = space.total
        }
    }

    func scanAll(clearFreedMessage: Bool = true) {
        guard !isScanning, !isCleaning else { return }
        isScanning = true
        if clearFreedMessage {
            lastFreedBytes = nil
        }
        for index in categories.indices {
            categories[index].isScanning = true
            categories[index].result = nil
        }

        Task {
            await withTaskGroup(of: (String, ScanResult).self) { group in
                for state in categories {
                    let category = state.category
                    group.addTask {
                        (category.id, CleanerEngine.scan(category))
                    }
                }
                for await (id, result) in group {
                    if let index = categories.firstIndex(where: { $0.id == id }) {
                        categories[index].result = result
                        categories[index].isScanning = false
                    }
                }
            }
            isScanning = false
            hasScanned = true
        }
    }

    func cleanSelected() {
        guard canClean else { return }
        isCleaning = true
        let targets = categories
            .filter { $0.isSelected && ($0.result?.totalBytes ?? 0) > 0 }
            .map { $0.category }

        Task {
            var freed: Int64 = 0
            for category in targets {
                let bytes = await Task.detached(priority: .userInitiated) {
                    CleanerEngine.clean(category)
                }.value
                freed += bytes
            }
            lastFreedBytes = freed
            isCleaning = false
            refreshDiskSpace()
            scanAll(clearFreedMessage: false)
        }
    }

    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
