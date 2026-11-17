import SwiftUI
import UIKit

enum Theme: String, CaseIterable, Sendable {
    case dark
    case light
}

extension Color {
    /// 页面底色（深色下接近黑，浅色下随系统）
    static let hgCanvas = Color(uiColor: .systemBackground)
    /// 卡片 / 列表底色
    static let hgSurface = Color(uiColor: .secondarySystemBackground)
    /// 更浅一层的控件底色
    static let hgSurface2 = Color(uiColor: .tertiarySystemBackground)
    static let hgSeparator = Color(uiColor: .separator)
    static let hgText = Color.primary
    static let hgTextSecondary = Color.secondary
    static let hgPrimary = Color(red: 0.376, green: 0.804, blue: 1.0)
    static let hgOnPrimary = Color.black
}
