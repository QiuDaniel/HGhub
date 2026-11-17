import Foundation
import Observation
import Valet

/// 会话：token 存 Keychain（Valet），用户资料随 token 一起编码保存。
@MainActor
@Observable
final class SessionStore {
    private let valet: Valet
    private let key = "session"
    private(set) var session: Session?

    init() {
        guard let identifier = Identifier(nonEmpty: "com.hghub.native") else {
            preconditionFailure("invalid Valet identifier")
        }
        let valet = Valet.valet(with: identifier, accessibility: .whenUnlocked)
        self.valet = valet

        if let text = try? valet.string(forKey: key),
           let data = text.data(using: .utf8) {
            self.session = try? JSONDecoder().decode(Session.self, from: data)
        }
    }

    var token: String? { session?.token }

    func set(token: String, user: User?) {
        let next = Session(token: token, user: user)
        session = next
        guard let data = try? JSONEncoder().encode(next),
              let text = String(data: data, encoding: .utf8) else { return }
        try? valet.setString(text, forKey: key)
    }

    func clear() {
        session = nil
        try? valet.removeObject(forKey: key)
    }
}
