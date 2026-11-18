import CFNetwork
import Darwin
import Foundation
import Nuke

struct NetworkDiagnostics: Sendable {
    let timestamp: String
    let base: String
    let host: String?
    let dns: [String]
    let dnsError: String?
    let proxy: String
    let httpStatus: Int?
    let httpMS: Int
    let httpError: String?

    var displayText: String {
        var lines: [String] = [
            "time: \(timestamp)",
            "base: \(base)",
            "host: \(host ?? "-")",
            "dns: \(dns.isEmpty ? (dnsError ?? "无结果") : dns.joined(separator: ", "))",
            "proxy: \(proxy)",
        ]
        if let httpStatus {
            lines.append("http: \(httpStatus) (\(httpMS)ms)")
        } else {
            lines.append("http: \(httpError ?? "失败") (\(httpMS)ms)")
        }
        return lines.joined(separator: "\n")
    }
}

struct UpdateInfo: Identifiable, Sendable {
    let current: String
    let latest: String
    let tag: String
    let hasUpdate: Bool
    let url: String
    let name: String
    let publishedAt: String
    let notes: String

    var id: String { "\(latest)-\(tag)" }
}

protocol MaintenanceService: Sendable {
    func clearCache() async
    func diagnostics() async -> NetworkDiagnostics
    func checkUpdate() async throws -> UpdateInfo
}

struct LiveMaintenanceService: MaintenanceService {
    let api: APIClient
    let session: URLSession
    let currentVersion: String

    private static let repo = "Minireel/HGhub"

    init(api: APIClient, session: URLSession = .shared) {
        self.api = api
        self.session = session
        self.currentVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.1.0"
    }

    func clearCache() async {
        ImagePipeline.shared.cache.removeAll()
        URLCache.shared.removeAllCachedResponses()
    }

    func diagnostics() async -> NetworkDiagnostics {
        let base = await api.currentBase
        let host = base.host
        let dns = host.map(resolveDNS) ?? (ips: [], error: "没有 host")

        let started = Date()
        var request = URLRequest(url: base.appendingPathComponent("/"))
        request.timeoutInterval = 8
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        var status: Int?
        var httpError: String?
        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                status = http.statusCode
            }
        } catch {
            httpError = error.localizedDescription
        }

        return NetworkDiagnostics(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            base: base.absoluteString,
            host: host,
            dns: dns.ips,
            dnsError: dns.error,
            proxy: systemProxyDescription(),
            httpStatus: status,
            httpMS: Int(Date().timeIntervalSince(started) * 1000),
            httpError: httpError
        )
    }

    func checkUpdate() async throws -> UpdateInfo {
        let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("HGhub-iOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("GitHub 无效响应")
        }

        if http.statusCode == 404 {
            return UpdateInfo(
                current: currentVersion,
                latest: "",
                tag: "",
                hasUpdate: false,
                url: "https://github.com/\(Self.repo)/releases",
                name: "",
                publishedAt: "",
                notes: ""
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode)
        }

        struct Release: Decodable {
            let tagName: String?
            let htmlUrl: String?
            let name: String?
            let publishedAt: String?
            let body: String?
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(Release.self, from: data)
        let tag = release.tagName ?? ""
        let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let hasUpdate = !tag.isEmpty && Self.isNewer(latest, than: currentVersion)

        return UpdateInfo(
            current: currentVersion,
            latest: latest,
            tag: tag,
            hasUpdate: hasUpdate,
            url: release.htmlUrl ?? "https://github.com/\(Self.repo)/releases",
            name: release.name ?? "",
            publishedAt: release.publishedAt ?? "",
            notes: String((release.body ?? "").prefix(800))
        )
    }

    // MARK: - Helpers

    static func versionParts(_ value: String) -> [Int] {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split { $0 == "." || $0 == "-" || $0 == "+" }
            .map { Int($0) ?? 0 }
    }

    static func isNewer(_ latest: String, than current: String) -> Bool {
        let a = versionParts(latest)
        let b = versionParts(current)
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }

    private func resolveDNS(_ host: String) -> (ips: [String], error: String?) {
        var hints = addrinfo(
            ai_flags: 0,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        let code = getaddrinfo(host, "443", &hints, &result)
        guard code == 0, let first = result else {
            return ([], String(cString: gai_strerror(code)))
        }
        defer { freeaddrinfo(first) }

        var ips = Set<String>()
        var pointer: UnsafeMutablePointer<addrinfo>? = first
        while let info = pointer {
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                info.pointee.ai_addr,
                info.pointee.ai_addrlen,
                &buffer,
                socklen_t(buffer.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                ips.insert(String(cString: buffer))
            }
            pointer = info.pointee.ai_next
        }
        return (Array(ips).sorted(), nil)
    }

    private func systemProxyDescription() -> String {
        guard let raw = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
              let settings = raw as? [String: Any] else {
            return "未读取（系统代理由 URLSession 自动使用）"
        }

        let httpHost = settings[kCFNetworkProxiesHTTPProxy as String] as? String
        let httpPort = settings[kCFNetworkProxiesHTTPPort as String] as? Int
        var parts: [String] = []
        if let httpHost { parts.append("HTTP \(httpHost):\(httpPort ?? 0)") }
        return parts.isEmpty ? "未配置（直连）" : parts.joined(separator: " · ")
    }
}
