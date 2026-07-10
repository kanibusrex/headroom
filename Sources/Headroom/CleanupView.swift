import SwiftUI

struct CleanupView: View {
    @ObservedObject var model: CleanerViewModel
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 20) {
            header
            diskGauge
            categoryList
            footer
        }
        .padding(24)
        .onAppear {
            if !model.hasScanned && !model.isScanning {
                model.scanAll()
            }
        }
        .confirmationDialog(
            "Clean \(formatBytes(model.selectedBytes)) of files?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clean Now", role: .destructive) {
                model.cleanSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected files will be permanently removed. Apps rebuild caches automatically.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cleanup")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Clear caches, temp files, and logs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let freed = model.lastFreedBytes {
                Label("Freed \(formatBytes(freed))", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.green.opacity(0.12), in: Capsule())
            }
        }
    }

    private var diskGauge: some View {
        let used = model.diskTotal - model.diskFree
        let fraction = model.diskTotal > 0 ? Double(used) / Double(model.diskTotal) : 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Startup Disk", systemImage: "internaldrive.fill")
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("\(formatBytes(model.diskFree)) free of \(formatBytes(model.diskTotal))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.accent, .purple],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * fraction))
                }
            }
            .frame(height: 10)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var categoryList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach($model.categories) { $state in
                    CategoryRow(state: $state)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                model.scanAll()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(model.isScanning || model.isCleaning)

            Button {
                showConfirmation = true
            } label: {
                Group {
                    if model.isCleaning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Clean \(formatBytes(model.selectedBytes))",
                              systemImage: "sparkles")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.accent)
            .disabled(!model.canClean)
        }
    }
}

private struct CategoryRow: View {
    @Binding var state: CleanerViewModel.CategoryState

    var body: some View {
        HStack(spacing: 14) {
            Toggle("", isOn: $state.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()

            Image(systemName: state.category.symbolName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38)
                .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(state.category.name)
                    .font(.body.weight(.semibold))
                Text(state.category.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if state.isScanning {
                ProgressView().controlSize(.small)
            } else if let result = state.result {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatBytes(result.totalBytes))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                    Text("\(result.itemCount) item\(result.itemCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .opacity(state.isSelected ? 1 : 0.55)
    }
}
