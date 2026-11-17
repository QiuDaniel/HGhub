import Foundation

struct Author: Decodable, Sendable, Hashable {
    let id: Int?
    let name: String?
    let avatar: String?
    let followers: Int?
}

/// 列表卡片。字段全部可选化，避免上游字段漂移导致整页解码失败。
struct VideoCard: Decodable, Identifiable, Sendable, Hashable {
    let id: Int
    let title: String?
    let cover: String?
    let description: String?
    let tags: [String]?
    let score: Double?
    let episodeCount: Int?
    let totalEpisodes: Int?
    let duration: String?
    let hot: Int?
    let likeCount: Int?
    let collectCount: Int?
    let commentCount: Int?
    let isFinished: Bool?
    let isOriginal: Int?
    let author: Author?
}
