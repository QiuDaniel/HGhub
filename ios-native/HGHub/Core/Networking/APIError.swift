import Foundation

/// 统一错误。Repository 层把上游/网络错误归一化到这里，UI 只认这个类型。
enum APIError: LocalizedError, Equatable, Sendable {
    case invalidURL
    case network(String)
    case timeout
    case unauthorized
    case http(Int)
    case business(String)
    case decoding(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "线路地址无效"
        case .network(let message):
            return "网络错误：\(message)"
        case .timeout:
            return "请求超时，请检查网络或切换线路"
        case .unauthorized:
            return "登录已过期，请重新登录"
        case .http(let code):
            return "服务异常（HTTP \(code)）"
        case .business(let message):
            return message
        case .decoding:
            return "数据解析失败"
        case .cancelled:
            return "请求已取消"
        }
    }
}
