import Foundation

/// 网络入口。所有业务请求都走这里：
/// - 普通接口 → `POST /api/edge/request` 信封
/// - 播放接口 → 直连 `POST /api/videos/{id}/episodes/{ep}/playback`
///
/// 用 actor 保护 base / token；由 `SessionStore` / `LineStore` 在登录、切线路时注入。
actor APIClient {
    private var base: URL
    private var token: String?
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder = JSONEncoder()

    init(base: URL? = nil, session: URLSession = .shared) {
        self.base = Self.normalize(base ?? Self.defaultBase)
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    // MARK: - 注入

    var currentBase: URL { base }

    func setBase(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return }
        base = Self.normalize(url)
    }

    func setToken(_ token: String?) {
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = (trimmed?.isEmpty == false) ? trimmed : nil
    }

    // MARK: - 业务

    func get<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T {
        try await edge(method: "GET", path: path, body: nil, as: type)
    }

    func post<T: Decodable & Sendable>(_ path: String, json: Data, as type: T.Type) async throws -> T {
        try await edge(method: "POST", path: path, body: json, as: type)
    }

    func delete<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T {
        try await edge(method: "DELETE", path: path, body: nil, as: type)
    }

    func post<T: Decodable & Sendable>(_ path: String, body: some Encodable, as type: T.Type) async throws -> T {
        let data = try encoder.encode(body)
        return try await post(path, json: data, as: type)
    }

    /// 只关心成功/业务错误、不关心 data 的写操作（点赞、收藏、关注、退出、发评论）。
    func postAction(_ path: String) async throws {
        try await action(method: "POST", path: path, body: nil)
    }

    func postAction(_ path: String, body: some Encodable) async throws {
        try await action(method: "POST", path: path, body: try encoder.encode(body))
    }

    func deleteAction(_ path: String) async throws {
        try await action(method: "DELETE", path: path, body: nil)
    }

    /// 播放接口：直连、body 必须是 `{}`、响应仍是 `{status,data}`。
    /// 非 401 的失败按契约回退到老 `GET /api/videos/{id}/play?ep=...`。
    func playback(id: Int, ep: Int) async throws -> PlayInfo {
        do {
            return try await directPlayback(id: id, ep: ep)
        } catch let error as APIError {
            if case .unauthorized = error { throw error }
            if let legacy = try? await legacyPlayback(id: id, ep: ep) {
                return legacy
            }
            throw error
        }
    }

    private func directPlayback(id: Int, ep: Int) async throws -> PlayInfo {
        let path = "/api/videos/\(id)/episodes/\(ep)/playback"
        let data = try await send(
            path: path,
            method: "POST",
            body: Data("{}".utf8),
            contentType: "application/json"
        )
        let payload: PlaybackPayload = try decodeEdge(data, as: PlaybackPayload.self)

        let streams = payload.streams
        let candidates = [streams?.main, streams?.hevc, streams?.preview]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let videoURL = candidates.first else {
            throw APIError.business("上游没有返回播放地址")
        }

        let cdn = payload.cdn.map { CDNInfo(authKey: $0.authKey, authValue: $0.authValue) }
        return PlayInfo(
            id: id,
            epNum: ep,
            title: "第\(ep)集",
            duration: 0,
            videoURL: videoURL,
            videoURLHEVC: streams?.hevc,
            cdn: cdn
        )
    }

    private func legacyPlayback(id: Int, ep: Int) async throws -> PlayInfo {
        let response: LegacyPlayback = try await get(
            "/api/videos/\(id)/play?ep=\(ep)&page_texts=0",
            as: LegacyPlayback.self
        )
        let url = response.videoUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !url.isEmpty else {
            throw APIError.business("老播放接口没有返回地址")
        }
        return PlayInfo(
            id: id,
            epNum: ep,
            title: "第\(ep)集",
            duration: 0,
            videoURL: url,
            videoURLHEVC: response.videoUrlHevc,
            cdn: nil
        )
    }

    // MARK: - 信封

    private func edge<T: Decodable & Sendable>(
        method: String,
        path: String,
        body: Data?,
        as type: T.Type
    ) async throws -> T {
        let envelope = EdgeEnvelope(method: method, path: path, body: body)
        let encoded = try encoder.encode(envelope)
        let data = try await send(
            path: "/api/edge/request",
            method: "POST",
            body: encoded,
            contentType: "application/json"
        )
        return try decodeEdge(data, as: type)
    }

    private func action(method: String, path: String, body: Data?) async throws {
        let envelope = EdgeEnvelope(method: method, path: path, body: body)
        let encoded = try encoder.encode(envelope)
        let data = try await send(
            path: "/api/edge/request",
            method: "POST",
            body: encoded,
            contentType: "application/json"
        )
        guard !data.isEmpty else { return }
        let status: EdgeStatus
        do {
            status = try decoder.decode(EdgeStatus.self, from: data)
        } catch {
            throw APIError.decoding(String(decoding: data.prefix(200), as: UTF8.self))
        }
        if status.status == 1 { return }
        if let message = status.msg?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            throw APIError.business(message)
        }
        throw APIError.business("接口返回失败")
    }

    private func decodeEdge<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        guard !data.isEmpty else {
            throw APIError.decoding("空响应")
        }
        let response: EdgeResponse<T>
        do {
            response = try decoder.decode(EdgeResponse<T>.self, from: data)
        } catch {
            throw APIError.decoding(String(decoding: data.prefix(200), as: UTF8.self))
        }
        if response.status == 1, let value = response.data {
            return value
        }
        if let message = response.msg?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            throw APIError.business(message)
        }
        throw APIError.business("接口返回失败")
    }

    // MARK: - HTTP

    private func send(
        path: String,
        method: String,
        body: Data?,
        contentType: String?
    ) async throws -> Data {
        guard let url = URL(string: base.absoluteString + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(base.absoluteString + "/", forHTTPHeaderField: "Referer")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue(contentType ?? "application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        var lastError: Error = APIError.network("未知错误")

        for attempt in 0..<3 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw APIError.network("无效响应")
                }
                switch http.statusCode {
                case 200..<300:
                    return data
                case 401, 403:
                    throw APIError.unauthorized
                default:
                    throw APIError.http(http.statusCode)
                }
            } catch let error as APIError {
                throw error
            } catch is CancellationError {
                throw APIError.cancelled
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(Int64(350 * (attempt + 1))))
                }
            }
        }

        if let urlError = lastError as? URLError, urlError.code == .timedOut {
            throw APIError.timeout
        }
        throw APIError.network(lastError.localizedDescription)
    }

    // MARK: - Helpers

    private static var defaultBase: URL {
        guard let url = URL(string: "https://huangguoai.com") else {
            preconditionFailure("invalid default base URL")
        }
        return url
    }

    private static func normalize(_ url: URL) -> URL {
        var text = url.absoluteString
        while text.hasSuffix("/") {
            text.removeLast()
        }
        return URL(string: text) ?? url
    }
}

// MARK: - 上游响应形状

private struct EdgeStatus: Decodable {
    let status: Int?
    let msg: String?
}

private struct EdgeResponse<T: Decodable>: Decodable {
    let status: Int?
    let msg: String?
    let data: T?
}

private struct LegacyPlayback: Decodable, Sendable {
    let videoUrl: String?
    let videoUrlHevc: String?
}

private struct PlaybackPayload: Decodable {
    let streams: Streams?
    let cdn: CDN?

    struct Streams: Decodable {
        let main: String?
        let hevc: String?
        let preview: String?
    }

    struct CDN: Decodable {
        let authKey: String?
        let authValue: String?
    }
}
