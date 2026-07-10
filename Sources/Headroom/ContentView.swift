import SwiftUI

enum Tool: String, CaseIterable, Identifiable {
    case cleanup
    case largeFiles
    case uninstaller

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cleanup: "Cleanup"
        case .largeFiles: "Large Files"
        case .uninstaller: "Uninstall Apps"
        }
    }

    var symbolName: String {
        switch self {
        case .cleanup: "sparkles"
        case .largeFiles: "doc.text.magnifyingglass"
        case .uninstaller: "trash.square"
        }
    }
}

struct ContentView: View {
    @State private var selectedTool: Tool = .cleanup
    @StateObject private var cleanerModel = CleanerViewModel()
    @StateObject private var largeFilesModel = LargeFilesViewModel()
    @StateObject private var uninstallerModel = UninstallerViewModel()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(width: 1)
            content
        }
        .frame(minWidth: 900, minHeight: 640)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 38, height: 38)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                Text("Headroom")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .padding(.bottom, 20)

            ForEach(Tool.allCases) { tool in
                SidebarButton(
                    tool: tool,
                    isSelected: selectedTool == tool
                ) {
                    selectedTool = tool
                }
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 210)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTool {
        case .cleanup:
            CleanupView(model: cleanerModel)
        case .largeFiles:
            LargeFilesView(model: largeFilesModel)
        case .uninstaller:
            UninstallerView(model: uninstallerModel)
        }
    }
}

private struct SidebarButton: View {
    let tool: Tool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tool.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                Text(tool.title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(isSelected ? Theme.accent : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                isSelected ? Theme.accent.opacity(0.12) : .clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
