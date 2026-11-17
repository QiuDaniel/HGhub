import Defaults
import Foundation
import Observation

/// 全局状态只放跨屏的四类：登录态、主题、全屏播放、登录弹层/Toast。
/// 视频列表、搜索词、播放进度属于 Feature 本地状态，不进这里。
@MainActor
@Observable
final class AppState {
    private static let themeKey = Defaults.Key<String>("hghub_theme", default: Theme.dark.rawValue)

    var session: Session?
    var theme: Theme {
        didSet {
            guard theme != oldValue else { return }
            Defaults[Self.themeKey] = theme.rawValue
        }
    }
    var feed: FeedContext?
    var loginPresented = false
    var toast: Toast?

    init() {
        self.theme = Theme(rawValue: Defaults[Self.themeKey]) ?? .dark
    }

    func apply(session: Session?) {
        self.session = session
    }

    func signOut() {
        session = nil
    }

    func showToast(_ message: String, icon: Toast.Icon = .info) {
        let next = Toast(message: message, icon: icon)
        toast = next
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(2200))
            guard let self, self.toast?.id == next.id else { return }
            self.toast = nil
        }
    }

    func showError(_ error: Error) {
        showToast(error.localizedDescription)
    }
}

struct Toast: Identifiable, Sendable {
    enum Icon: String, Sendable {
        case info
        case ok
        case heart
        case star
    }

    let id: UUID
    let message: String
    let icon: Icon

    init(message: String, icon: Icon = .info) {
        self.id = UUID()
        self.message = message
        self.icon = icon
    }
}
