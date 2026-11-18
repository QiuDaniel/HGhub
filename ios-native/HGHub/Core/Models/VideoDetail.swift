import Foundation

/// 上游 duration 有时是数字、有时是字符串（详情 fixture 为 "820"），统一兜底。
struct FlexibleDouble: Decodable, Sendable, Hashable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let number = try? container.decode(Double.self) {
            value = number
        } else if let integer = try? container.decode(Int.self) {
            value = Double(integer)
        } else if let text = try? container.decode(String.self) {
            value = Double(text)
        } else {
            value = nil
        }
    }
}

struct VideoDetail: Decodable, Sendable, Hashable, Identifiable {
    struct Episode: Decodable, Sendable, Hashable, Identifiable {
        let epNum: Int
        let title: String?
        let duration: Double?
        let status: Int?

        var id: Int { epNum }

        enum CodingKeys: String, CodingKey {
            case epNum = "ep_num"
            case title
            case duration
            case status
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            epNum = try container.decodeIfPresent(Int.self, forKey: .epNum) ?? 0
            title = try container.decodeIfPresent(String.self, forKey: .title)
            duration = try container.decodeIfPresent(Double.self, forKey: .duration)
            status = try container.decodeIfPresent(Int.self, forKey: .status)
        }

        init(epNum: Int, title: String? = nil, duration: Double? = nil, status: Int? = nil) {
            self.epNum = epNum
            self.title = title
            self.duration = duration
            self.status = status
        }
    }

    struct Counts: Decodable, Sendable, Hashable {
        let collect: Int?
        let comment: Int?
        let hot: Int?
        let like: Int?
    }

    struct AuthorInfo: Decodable, Sendable, Hashable {
        let id: Int?
        let name: String?
        let avatar: String?
        let followers: Int?
        let following: Int?
        let isFollowing: Bool?
        let likeCount: Int?
    }

    struct Interaction: Decodable, Sendable, Hashable {
        let collected: Bool?
        let liked: Bool?
        let likedEp: Int?
    }

    let id: Int
    let title: String?
    let cover: String?
    let description: String?
    let tags: [String]?
    let tagLinks: [TagLink]?
    let score: Double?
    let episodeCount: Int?
    let totalEpisodes: Int?
    let episodes: [Episode]?
    let counts: Counts?
    let author: AuthorInfo?
    let interaction: Interaction?
    let isFinished: Bool?
    let isOriginal: Int?
    let videoType: Int?
    let duration: FlexibleDouble?
    let createdAt: String?

    struct TagLink: Decodable, Sendable, Hashable {
        let name: String?
        let url: String?
    }

    var displayTitle: String {
        let text = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "未命名视频" : text
    }

    var authorName: String {
        let text = author?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "匿名作者" : text
    }

    /// 上游偶尔把 total_episodes 给 0；优先用真实 episodes 数组，再退回集数字段。
    var episodeTotal: Int {
        let listCount = episodes?.filter { $0.epNum > 0 }.count ?? 0
        return max(listCount, episodeCount ?? 0, totalEpisodes ?? 0, 1)
    }

    var episodeList: [Episode] {
        if let episodes, !episodes.isEmpty {
            return episodes.sorted { $0.epNum < $1.epNum }
        }
        return (1...episodeTotal).map { Episode(epNum: $0, title: "第\($0)集") }
    }
}
