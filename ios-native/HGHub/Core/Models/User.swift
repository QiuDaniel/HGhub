import Foundation

struct User: Codable, Sendable, Hashable, Identifiable {
    let id: Int
    let username: String?
    let nickname: String?
    let avatar: String?
}

struct Session: Codable, Sendable, Equatable {
    var token: String
    var user: User?
}
