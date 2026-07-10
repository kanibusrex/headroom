import SwiftUI

@MainActor
final class UninstallerViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var selectedApp: InstalledApp?
    @Published var leftovers: [LeftoverItem] = []
    @Published var isLoadingLeftovers = false
    @Published var isUninstalling = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    var filteredApps: [InstalledApp] {
        searchText.isEmpty
            ? apps
            : apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func loadApps() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            let found = await Task.detached(priority: .userInitiated) {
                AppUninstaller.installedApps()
            }.value
            apps = found
            isLoading = false
            hasLoaded = true

            await withTaskGroup(of: (String, Int64).self) { group in
                for app in found {
                    group.addTask {
                        (app.id, CleanerEngine.allocatedSize(of: app.url))
                    }
                }
                for await (id, size) in group {
                    if let index = apps.firstIndex(where: { $0.id == id }) {
                        apps[index].size = size
                    }
                }
            }
        }
    }

    func select(_ app: InstalledApp) {
        selectedApp = app
        leftovers = []
        isLoadingLeftovers = true

        Task {
            let items = await Task.detached(priority: .userInitiated) {
                AppUninstaller.leftovers(for: app)
            }.value
            guard selectedApp?.id == app.id else { return }
            leftovers = items
            isLoadingLeftovers = false
        }
    }

    func uninstallSelected() {
        guard let app = selectedApp, !isUninstalling else { return }
        let urls = [app.url] + leftovers.map(\.url)
        isUninstalling = true

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                AppUninstaller.moveToTrash(urls)
            }.value
            isUninstalling = false
            selectedApp = nil

            if result.errors.isEmpty {
                statusMessage = "Moved \(app.name) to Trash (\(formatBytes(result.freed)))"
            } else {
                errorMessage = result.errors.joined(separator: "\n")
            }
            isLoading = false
            loadApps()
        }
    }
}

struct UninstallerView: View {
    @ObservedObject var model: UninstallerViewModel
    @Environment(\.screenshotMode) private var screenshotMode

    var body: some View {
        // Presentation modifiers dim the whole view under ImageRenderer,
        // so screenshot mode renders the bare content.
        if screenshotMode {
            core
        } else {
            interactive
        }
    }

    private var core: some View {
        VStack(spacing: 20) {
            header
            appList
        }
        .padding(24)
        .onAppear {
            if !model.hasLoaded && !model.isLoading {
                model.loadApps()
            }
        }
    }

    private var interactive: some View {
        core
        .sheet(item: $model.selectedApp) { app in
            UninstallSheet(model: model, app: app)
        }
        .alert("Some items couldn't be moved", isPresented: .init(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Uninstall Apps")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Remove apps and their leftover files")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let status = model.statusMessage {
                Label(status, systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.green.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                if screenshotMode {
                    Text("Search")
                        .foregroundStyle(.tertiary)
                        .frame(width: 140, alignment: .leading)
                } else {
                    TextField("Search", text: $model.searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 140)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.card, in: Capsule())
        }
    }

    private var appList: some View {
        Group {
            if model.isLoading && model.apps.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Finding installed apps…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SnapshotFriendlyScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.filteredApps) { app in
                            AppRow(app: app) {
                                model.select(app)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct AppRow: View {
    let app: InstalledApp
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                FileIcon(path: app.url.path, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.body.weight(.medium))
                    Text(app.url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let size = app.size {
                    Text(formatBytes(size))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                } else {
                    ProgressView().controlSize(.mini)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct UninstallSheet: View {
    @ObservedObject var model: UninstallerViewModel
    let app: InstalledApp
    @State private var showConfirmation = false

    private var totalBytes: Int64 {
        (app.size ?? 0) + model.leftovers.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                    .resizable()
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.title3.weight(.bold))
                    if let id = app.bundleID {
                        Text(id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(formatBytes(totalBytes))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Will be moved to Trash")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        LeftoverRow(name: app.url.path, size: app.size ?? 0, symbol: "app.fill")
                        if model.isLoadingLeftovers {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Looking for leftover files…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        } else {
                            ForEach(model.leftovers) { item in
                                LeftoverRow(
                                    name: item.url.path.replacingOccurrences(
                                        of: NSHomeDirectory(), with: "~"),
                                    size: item.size,
                                    symbol: "doc.fill"
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    model.selectedApp = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    showConfirmation = true
                } label: {
                    Group {
                        if model.isUninstalling {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Uninstall", systemImage: "trash")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                .disabled(model.isUninstalling || model.isLoadingLeftovers)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Color(red: 0.11, green: 0.12, blue: 0.16))
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "Uninstall \(app.name)?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                model.uninstallSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The app and \(model.leftovers.count) related item\(model.leftovers.count == 1 ? "" : "s") will be moved to the Trash.")
        }
    }
}

private struct LeftoverRow: View {
    let name: String
    let size: Int64
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(Theme.accent)
            Text(name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(formatBytes(size))
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
