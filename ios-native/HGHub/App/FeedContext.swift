import Foundation

/// 全屏播放的上下文。从首页/搜索/分类/我的都能构造，交给根视图的 fullScreenCover。
struct FeedContext: Identifiable, Hashable, Sendable {
    let id: UUID
    var cards: [VideoCard]
    var index: Int
    var title: String
    var source: String
    var startEp: Int?
    var startTime: Double?
    var page: Int
    var pages: Int

    var videoIDs: [Int] { cards.map(\.id) }

    init(
        cards: [VideoCard],
        index: Int,
        title: String,
        source: String = "home",
        startEp: Int? = nil,
        startTime: Double? = nil,
        page: Int = 1,
        pages: Int = 1
    ) {
        self.id = UUID()
        self.cards = cards
        self.index = max(0, min(index, max(cards.count - 1, 0)))
        self.title = title
        self.source = source
        self.startEp = startEp
        self.startTime = startTime
        self.page = page
        self.pages = pages
    }

    /// 兼容只传 id 的旧入口；M2 首页会传完整 cards。
    init(
        videoIDs: [Int],
        index: Int,
        title: String,
        source: String = "home",
        startEp: Int? = nil,
        startTime: Double? = nil
    ) {
        self.init(
            cards: videoIDs.map { id in
                VideoCard(id: id)
            },
            index: index,
            title: title,
            source: source,
            startEp: startEp,
            startTime: startTime
        )
    }
}

extension VideoCard {
    init(
        id: Int,
        title: String? = nil,
        cover: String? = nil,
        episodeCount: Int? = nil,
        score: Double? = nil,
        likeCount: Int? = nil,
        author: Author? = nil
    ) {
        self.id = id
        self.title = title
        self.cover = cover
        self.description = nil
        self.tags = nil
        self.score = score
        self.episodeCount = episodeCount
        self.totalEpisodes = episodeCount
        self.duration = nil
        self.hot = nil
        self.likeCount = likeCount
        self.collectCount = nil
        self.commentCount = nil
        self.isFinished = nil
        self.isOriginal = nil
        self.author = author
    }

    var episodeTotal: Int {
        max(episodeCount ?? totalEpisodes ?? 1, 1)
    }

    var displayTitle: String {
        let text = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "未命名视频" : text
    }

    var authorName: String {
        let text = author?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "匿名作者" : text
    }
}
