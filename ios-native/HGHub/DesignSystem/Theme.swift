import SwiftUI

enum Theme: String, CaseIterable, Sendable {
    case dark
    case light
}

extension Color {
    static let hgCanvas = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let hgPrimary = Color(red: 0.376, green: 0.804, blue: 1.0)
}
