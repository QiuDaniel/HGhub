import Foundation

enum RankKind: String, CaseIterable, Identifiable, Sendable {
    case hot
    case recommend
    case potential

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hot: return "热播榜"
        case .recommend: return "推荐榜"
        case .potential: return "潜力榜"
        }
    }

    var subtitle: String {
        switch self {
        case .hot: return "按热力指数排序"
        case .recommend: return "按推荐值排序"
        case .potential: return "按潜力值排序"
        }
    }
}

struct RankItem: Decodable, Sendable, Hashable, Identifiable {
    struct Metrics: Decodable, Sendable, Hashable {
        let collect: Int?
        let comment: Int?
        let like: Int?
        let play: Int?
    }

    let rank: Int?
    let videoID: Int
    let title: String?
    let cover: String?
    let tags: [String]?
    let score: Double?
    let cateName: String?
    let episodeCount: Int?
    let isFinished: Bool?
    let metricLabel: String?
    let metricValue: Int?
    let metrics: Metrics?

    enum CodingKeys: String, CodingKey {
        case rank
        case videoID = "videoId"
        case title
        case cover
        case tags
        case score
        case cateName
        case episodeCount
        case isFinished
        case metricLabel
        case metricValue
        case metrics
    }

    var id: Int { videoID }

    var displayTitle: String {
        let value = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "未命名视频" : value
    }

    var episodeTotal: Int { max(episodeCount ?? 1, 1) }

    var card: VideoCard {
        VideoCard(
            id: videoID,
            title: title,
            cover: cover,
            episodeCount: episodeCount,
            score: score,
            likeCount: metrics?.like
        )
    }
}

struct RankPage: Decodable, Sendable {
    let type: String?
    let items: [RankItem]

    enum CodingKeys: String, CodingKey {
        case type
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        items = try container.decodeIfPresent([RankItem].self, forKey: .items) ?? []
    }

    init(type: String?, items: [RankItem]) {
        self.type = type
        self.items = items
    }
}

struct ChannelInfo: Identifiable, Hashable, Sendable {
    let cate: String
    let name: String
    let desc: String

    var id: String { cate }

    static let all: [ChannelInfo] = [
        ChannelInfo(cate: "24", name: "AI成人短剧", desc: "高能反转 · 一口气看完"),
        ChannelInfo(cate: "25", name: "AI成人漫剧", desc: "国创漫剧 · 每周更新"),
        ChannelInfo(cate: "26", name: "AI换脸", desc: "换脸演绎 · 全新剧情"),
        ChannelInfo(cate: "27", name: "AI魔改", desc: "魔改名场面 · 脑洞大开"),
    ]
}
