import Foundation

/// 上游 `/api/edge/request` 的信封。
///
/// 真实请求的 method/path/body 都塞进这个 JSON：
/// - `body` 是 base64(JSON UTF-8)，无 body 时为空串
/// - `content_type` 无 body 时为空串
struct EdgeEnvelope: Encodable, Sendable {
    let method: String
    let path: String
    let body: String
    let contentType: String

    enum CodingKeys: String, CodingKey {
        case method
        case path
        case body
        case contentType = "content_type"
    }

    init(method: String, path: String, body: Data?) {
        self.method = method
        self.path = path
        self.body = body?.base64EncodedString() ?? ""
        self.contentType = body == nil ? "" : "application/json"
    }
}
