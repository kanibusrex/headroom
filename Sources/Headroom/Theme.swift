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

func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
