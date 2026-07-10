import SwiftUI

enum Theme {
    static let accent = Color(red: 0.35, green: 0.78, blue: 0.98)
    static let card = Color.white.opacity(0.05)

    static let background = LinearGradient(
        colors: [Color(red: 0.09, green: 0.10, blue: 0.14),
                 Color(red: 0.05, green: 0.05, blue: 0.08)],
        startPoint: .top,
        endPoint: .bottom
    )
}

private let byteFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowsNonnumericFormatting = false
    return formatter
}()

func formatBytes(_ bytes: Int64) -> String {
    byteFormatter.string(fromByteCount: bytes)
}

// MARK: - Screenshot-mode support
// ImageRenderer (used by `--screenshot`) can't render ScrollView contents or
// AppKit-backed controls (Toggle, Picker, TextField), so views swap in
// SwiftUI-drawn equivalents when this flag is set.

private struct ScreenshotModeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var screenshotMode: Bool {
        get { self[ScreenshotModeKey.self] }
        set { self[ScreenshotModeKey.self] = newValue }
    }
}

struct SnapshotFriendlyScrollView<Content: View>: View {
    @Environment(\.screenshotMode) private var screenshotMode
    @ViewBuilder let content: () -> Content

    var body: some View {
        if screenshotMode {
            VStack(spacing: 0) {
                content()
                Spacer(minLength: 0)
            }
        } else {
            ScrollView { content() }
        }
    }
}

/// Icons for screenshot mode, decoded with ImageIO only. Touching NSWorkspace
/// or NSImage rasterization anywhere in the process makes every later
/// ImageRenderer frame come out dimmed, so this path must stay AppKit-free.
@MainActor
enum IconStore {
    static var icons: [String: CGImage] = [:]

    static func preloadAppIcons(appURLs: [URL]) {
        for url in appURLs where icons[url.path] == nil {
            guard let bundle = Bundle(url: url) else { continue }
            var iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
            if iconName.hasSuffix(".icns") {
                iconName = String(iconName.dropLast(5))
            }
            guard let iconURL = bundle.url(forResource: iconName, withExtension: "icns"),
                  let image = decodeImage(at: iconURL) else { continue }
            icons[url.path] = image
        }
    }

    /// Smallest representation that's still at least 128px, for crisp thumbnails.
    private static func decodeImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        var best: CGImage?
        for index in 0..<CGImageSourceGetCount(source) {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            if best == nil
                || (image.width >= 128 && image.width < best!.width)
                || (best!.width < 128 && image.width > best!.width) {
                best = image
            }
        }
        return best
    }
}

struct FileIcon: View {
    @Environment(\.screenshotMode) private var screenshotMode
    let path: String
    let size: CGFloat

    var body: some View {
        if screenshotMode {
            if let cgImage = IconStore.icons[path] {
                Image(cgImage, scale: 2, label: Text(""))
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 0.62))
                    .foregroundStyle(Theme.accent.opacity(0.75))
                    .frame(width: size, height: size)
            }
        } else {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: size, height: size)
        }
    }

    private var fallbackSymbol: String {
        switch (path as NSString).pathExtension.lowercased() {
        case "heic", "jpg", "jpeg", "png", "gif", "tiff", "raw": "photo.fill"
        case "mov", "mp4", "mkv", "avi": "film.fill"
        case "zip", "tar", "gz", "xz", "dmg", "pkg": "archivebox.fill"
        case "app": "app.fill"
        case "exe", "appimage", "": "gearshape.2.fill"
        default: "doc.fill"
        }
    }
}

struct SnapshotFriendlyCheckbox: View {
    @Environment(\.screenshotMode) private var screenshotMode
    @Binding var isOn: Bool

    var body: some View {
        if screenshotMode {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 15))
                .foregroundStyle(isOn ? Theme.accent : .secondary)
        } else {
            Toggle("", isOn: $isOn)
                .toggleStyle(.checkbox)
                .labelsHidden()
        }
    }
}
