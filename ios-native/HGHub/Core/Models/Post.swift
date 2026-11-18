import Foundation

struct Post: Decodable, Sendable, Hashable, Identifiable {
    struct Author: Decodable, Sendable, Hashable {
        let id: Int?
        let name: String?
        let avatar: String?
        let isFollowing: Bool?
    }

    struct Counts: Decodable, Sendable, Hashable {
        let like: Int?
        let comment: Int?
        let collect: Int?
        let share: Int?
        let hot: Int?
    }

    struct Interaction: Decodable, Sendable, Hashable {
        let liked: Bool?
        let collected: Bool?
    }

    let id: Int
    let title: String?
    let desc: String?
    let content: String?
    let cover: String?
    let tags: [String]?
    let hot: Int?
    let videoURL: String?
    let videoID: Int?
    let author: Author?
    let counts: Counts?
    let interaction: Interaction?
    let createdAt: String?
    let publishTime: String?

    var displayTitle: String {
        let value = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "未命名帖子" : value
    }

    var displayAuthor: String {
        let value = author?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "黄果吃瓜" : value
    }

    var displayTime: String {
        let value = (publishTime ?? createdAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "" : value
    }
}
