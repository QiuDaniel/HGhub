import Foundation

struct Comment: Decodable, Sendable, Hashable, Identifiable {
    let id: Int
    let userId: Int?
    let nickname: String?
    let avatar: String?
    let avatarColor: String?
    let content: String?
    let text: String?
    let time: String?
    let createdAt: String?
    let likeCount: Int?
    let liked: Bool?
    let replyCount: Int?
    let replyId: Int?
    let replyList: [Comment]?
    let isPinned: Bool?
    let ipRegion: String?

    var displayText: String {
        let value = (content ?? text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "（空评论）" : value
    }

    var displayName: String {
        let value = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "匿名用户" : value
    }

    var displayTime: String {
        let value = (time ?? createdAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "" : value
    }

    var replies: [Comment] { replyList ?? [] }
}

struct CommentPage: Decodable, Sendable {
    let ep: Int
    let revision: String?
    let reset: Bool?
    let items: [Comment]
    let pagination: Pagination

    enum CodingKeys: String, CodingKey {
        case ep
        case revision
        case reset
        case items
        case pagination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ep = try container.decodeIfPresent(Int.self, forKey: .ep) ?? 1
        revision = try container.decodeIfPresent(String.self, forKey: .revision)
        reset = try container.decodeIfPresent(Bool.self, forKey: .reset)
        let items = try container.decodeIfPresent([Comment].self, forKey: .items) ?? []
        self.items = items
        self.pagination = try container.decodeIfPresent(Pagination.self, forKey: .pagination)
            ?? Pagination(page: 1, pages: 1, size: items.count, total: items.count)
    }

    init(ep: Int, items: [Comment], pagination: Pagination) {
        self.ep = ep
        self.revision = nil
        self.reset = nil
        self.items = items
        self.pagination = pagination
    }
}

struct LoginResponse: Decodable, Sendable {
    let token: String?
    let user: User?
}
