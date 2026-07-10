import SwiftUI

@MainActor
final class LargeFilesViewModel: ObservableObject {
    @Published var files: [LargeFile] = []
    @Published var selection = Set<String>()
    @Published var isScanning = false
    @Published var isTrashing = false
    @Published var hasScanned = false
    @Published var minSizeMB = 100
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    var selectedFiles: [LargeFile] {
        files.filter { selection.contains($0.id) }
    }

    var selectedBytes: Int64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }

    func scan() {
        guard !isScanning, !isTrashing else { return }
        isScanning = true
        statusMessage = nil
        selection.removeAll()
        let minBytes = Int64(minSizeMB) * 1_000_000

        Task {
            files = await Task.detached(priority: .userInitiated) {
                LargeFileScanner.scan(minBytes: minBytes)
            }.value
            isScanning = false
            hasScanned = true
        }
    }

    func trashSelected() {
        let targets = selectedFiles.map(\.url)
        guard !targets.isEmpty, !isTrashing else { return }
        isTrashing = true

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                LargeFileScanner.moveToTrash(targets)
            }.value
            isTrashing = false

            let trashedPaths = Set(targets.map(\.path))
            files.removeAll { trashedPaths.contains($0.url.path) }
            selection.removeAll()

            if result.errors.isEmpty {
                statusMessage = "Moved \(targets.count) item\(targets.count == 1 ? "" : "s") (\(formatBytes(result.freed))) to Trash"
            } else {
                errorMessage = result.errors.joined(separator: "\n")
            }
        }
    }
}

struct LargeFilesView: View {
    @ObservedObject var model: LargeFilesViewModel
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 20) {
            header
            fileList
            footer
        }
        .padding(24)
        .onAppear {
            if !model.hasScanned && !model.isScanning {
                model.scan()
            }
        }
        .confirmationDialog(
            "Move \(model.selection.count) file\(model.selection.count == 1 ? "" : "s") (\(formatBytes(model.selectedBytes))) to Trash?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                model.trashSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can restore them from the Trash until it's emptied.")
        }
        .alert("Some files couldn't be moved", isPresented: .init(
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
                Text("Large Files")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Biggest files in your home folder")
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

            Picker("Min size", selection: $model.minSizeMB) {
                Text("100 MB+").tag(100)
                Text("500 MB+").tag(500)
                Text("1 GB+").tag(1000)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .disabled(model.isScanning)
            .onChange(of: model.minSizeMB) {
                model.scan()
            }
        }
    }

    private var fileList: some View {
        Group {
            if model.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning your home folder…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.files.isEmpty && model.hasScanned {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("No files over \(model.minSizeMB >= 1000 ? "1 GB" : "\(model.minSizeMB) MB") found")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.files) { file in
                            LargeFileRow(
                                file: file,
                                isSelected: model.selection.contains(file.id)
                            ) { selected in
                                if selected {
                                    model.selection.insert(file.id)
                                } else {
                                    model.selection.remove(file.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                model.scan()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(model.isScanning || model.isTrashing)

            Button {
                showConfirmation = true
            } label: {
                Group {
                    if model.isTrashing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Move \(formatBytes(model.selectedBytes)) to Trash",
                              systemImage: "trash")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.accent)
            .disabled(model.selection.isEmpty || model.isScanning || model.isTrashing)
        }
    }
}

private struct LargeFileRow: View {
    let file: LargeFile
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: .init(get: { isSelected }, set: onToggle))
                .toggleStyle(.checkbox)
                .labelsHidden()

            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable()
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.lastPathComponent)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(file.url.deletingLastPathComponent().path
                    .replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if let modified = file.modified {
                Text(modified.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(formatBytes(file.size))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .frame(width: 84, alignment: .trailing)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}
