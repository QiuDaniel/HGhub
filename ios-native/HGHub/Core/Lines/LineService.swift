import Foundation
import Observation

struct LineProbe: Identifiable, Sendable, Hashable {
    let url: String
    let ok: Bool
    let status: Int?
    let ms: Int
    let error: String?

    var id: String { url }

    var display: String {
        if ok { return "\(ms)ms" }
        if let status { return "HTTP \(status)" }
        return "失败"
    }
}

@MainActor
@Observable
final class LineService {
    let lines: LineStore
    private let api: APIClient
    private let session: URLSession

    private(set) var mirrors: [LineStore.Line] = []
    private(set) var isLoadingMirrors = false
    private(set) var mirrorError: String?
    private(set) var probes: [String: LineProbe] = [:]
    private(set) var isProbing = false

    init(lines: LineStore, api: APIClient, session: URLSession = .shared) {
        self.lines = lines
        self.api = api
        self.session = session
    }

    var mirrorSource: String { "https://huangguoai.pages.dev/" }

    func loadMirrors(force: Bool = false) async {
        guard !isLoadingMirrors else { return }
        if !force, !mirrors.isEmpty { return }

        isLoadingMirrors = true
        mirrorError = nil
        defer { isLoadingMirrors = false }

        do {
            let pageURL = URL(string: mirrorSource)!
            let html = try await text(from: pageURL)
            let relative = PublishParser.scriptSource(in: html) ?? "publish.js"
            let scriptURL = URL(string: PublishParser.absolute(base: mirrorSource, relative: relative))
                ?? pageURL.appendingPathComponent("publish.js")
            let js = try await text(from: scriptURL)

            guard let urls = PublishParser.mirrorURLs(js: js) else {
                throw APIError.business("地址发布页格式有变化：没有找到可用镜像")
            }

            mirrors = urls.compactMap { url in
                guard let host = URL(string: url)?.host else { return nil }
                return LineStore.Line(name: host, url: url)
            }
        } catch {
            mirrors = []
            mirrorError = error.localizedDescription
        }
    }

    @discardableResult
    func select(_ line: LineStore.Line) async -> Bool {
        guard lines.select(line) else { return false }
        await api.setBase(lines.currentURL)
        return true
    }

    func probe(_ urls: [String]) async {
        guard !isProbing else { return }
        isProbing = true
        defer { isProbing = false }

        let unique = Array(Set(urls)).sorted()
        for chunk in unique.chunked(into: 6) {
            await withTaskGroup(of: LineProbe.self) { group in
                for url in chunk {
                    group.addTask { [session] in
                        await Self.probeOne(url: url, session: session)
                    }
                }
                for await result in group {
                    probes[result.url] = result
                }
            }
        }
    }

    private func text(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("text/html,application/javascript,*/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("无效响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw APIError.decoding("发布页不是 UTF-8")
        }
        return text
    }

    private nonisolated static func probeOne(url: String, session: URLSession) async -> LineProbe {
        let started = Date()
        guard let parsed = URL(string: url),
              let scheme = parsed.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              parsed.host != nil else {
            return LineProbe(url: url, ok: false, status: nil, ms: 0, error: "地址无效")
        }

        var request = URLRequest(url: parsed)
        request.timeoutInterval = 8
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        do {
            let (_, response) = try await session.data(for: request)
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            if let http = response as? HTTPURLResponse {
                return LineProbe(url: url, ok: http.statusCode < 400, status: http.statusCode, ms: ms, error: nil)
            }
            return LineProbe(url: url, ok: true, status: nil, ms: ms, error: nil)
        } catch {
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            return LineProbe(url: url, ok: false, status: nil, ms: ms, error: error.localizedDescription)
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
