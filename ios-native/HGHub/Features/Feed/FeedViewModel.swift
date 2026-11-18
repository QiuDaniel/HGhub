import Foundation
import Observation

/// 全屏 Feed 的本地状态：当前 index、已经加载的卡片、后续分页。
@MainActor
@Observable
final class FeedViewModel {
    private let videos: VideoRepository
    private let discovery: VideoDiscoveryRepository?
    private let source: String
    private let query: String?
    private let cate: String?

    private(set) var cards: [VideoCard]
    var index: Int
    private(set) var page: Int
    private(set) var pages: Int
    private(set) var isLoadingMore = false
    var error: String?

    private var seen: Set<Int>

    init(
        context: FeedContext,
        videos: VideoRepository,
        discovery: VideoDiscoveryRepository? = nil
    ) {
        self.videos = videos
        self.discovery = discovery
        self.source = context.source
        self.query = context.query
        self.cate = context.cate
        self.cards = context.cards
        self.index = max(0, min(context.index, max(context.cards.count - 1, 0)))
        let startPage = max(context.page, 1)
        self.page = startPage
        self.pages = max(context.pages, startPage)
        self.seen = Set(context.cards.map(\.id))
    }

    var current: VideoCard? {
        guard cards.indices.contains(index) else { return nil }
        return cards[index]
    }

    var hasMore: Bool { page < pages }

    func loadMoreIfNeeded(at index: Int) async {
        guard !isLoadingMore, hasMore else { return }
        guard index >= cards.count - 3 else { return }

        isLoadingMore = true
        error = nil
        defer { isLoadingMore = false }

        do {
            let response = try await fetch(page: page + 1)
            guard !Task.isCancelled else { return }
            for card in response.items where seen.insert(card.id).inserted {
                cards.append(card)
            }
            page = max(response.pagination.page, page + 1)
            pages = max(response.pagination.pages, page)
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func fetch(page: Int) async throws -> Paged<VideoCard> {
        switch source {
        case "search":
            if let discovery, let query, !query.isEmpty {
                return try await discovery.search(query: query, page: page, size: 10)
            }
        case "channel":
            if let discovery, let cate {
                return try await discovery.category(cate: cate, page: page, size: 10)
            }
        default:
            break
        }
        return try await videos.feed(page: page, size: 10)
    }

    func select(_ next: Int) {
        guard !cards.isEmpty else { return }
        index = max(0, min(next, cards.count - 1))
    }

    func episodes(for card: VideoCard) -> Int {
        card.episodeTotal
    }
}
