import Foundation

protocol AccountRepository: Sendable {
    func login(username: String, password: String) async throws -> Session
    func logout() async throws
    func me() async throws -> User
}

struct LiveAccountRepository: AccountRepository {
    let api: APIClient

    private struct LoginRequest: Encodable {
        let username: String
        let password: String
    }

    func login(username: String, password: String) async throws -> Session {
        let response = try await api.post(
            "/api/account/loginByPassword",
            body: LoginRequest(username: username, password: password),
            as: LoginResponse.self
        )
        guard let token = response.token?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            throw APIError.business("登录返回缺少 token")
        }
        return Session(token: token, user: response.user)
    }

    func logout() async throws {
        try await api.postAction("/api/account/logout")
    }

    func me() async throws -> User {
        try await api.get("/api/account/me", as: User.self)
    }
}
