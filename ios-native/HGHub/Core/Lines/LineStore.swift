import Defaults
import Foundation
import Observation

/// 线路（上游 base URL）。M1 只做固定线路 + 持久化；
/// 镜像解析、发布页抓取和探测在 M5 接入。
@MainActor
@Observable
final class LineStore {
    struct Line: Identifiable, Hashable, Sendable {
        let name: String
        let url: String
        var id: String { url }
    }

    static let fixed: [Line] = [
        Line(name: "固定线路 1", url: "https://huangguoai.com"),
        Line(name: "固定线路 2", url: "https://huangguoai.ai"),
    ]

    @ObservationIgnored private let baseKey: Defaults.Key<String>
    private(set) var current: Line

    init(suite: UserDefaults = .standard, namespace: String = "hghub") {
        let baseKey = Defaults.Key<String>("\(namespace)_line", default: Self.fixed[0].url, suite: suite)
        self.baseKey = baseKey

        let saved = Defaults[baseKey]
        self.current = Self.line(for: saved) ?? Self.fixed[0]
    }

    var currentURL: URL {
        URL(string: current.url) ?? Self.fallbackURL
    }

    @discardableResult
    func select(_ line: Line) -> Bool {
        select(url: line.url)
    }

    @discardableResult
    func select(url: String) -> Bool {
        guard let normalized = Self.normalized(url) else { return false }
        let next = Self.line(for: normalized)
            ?? Line(name: Self.host(of: normalized) ?? normalized, url: normalized)
        current = next
        Defaults[baseKey] = next.url
        return true
    }

    // MARK: - Helpers

    /// 仅接受 http(s) + host，并去掉结尾 `/`。
    static func normalized(_ url: String) -> String? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              parsed.host != nil else { return nil }

        var text = trimmed
        while text.hasSuffix("/") {
            text.removeLast()
        }
        return text
    }

    /// 已存在的固定线路返回原名；其他合法地址按 host 命名。
    static func line(for url: String) -> Line? {
        let normalized = normalized(url) ?? url
        if let fixed = fixed.first(where: { $0.url == normalized }) {
            return fixed
        }
        guard let host = host(of: normalized) else { return nil }
        return Line(name: host, url: normalized)
    }

    static func host(of url: String) -> String? {
        URL(string: url)?.host
    }

    private static var fallbackURL: URL {
        guard let url = URL(string: fixed[0].url) else {
            preconditionFailure("invalid default line")
        }
        return url
    }
}
