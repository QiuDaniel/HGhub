import Foundation
import Testing
@testable import HGHub

private actor StubVideoRepository: VideoRepository {
    private var page: Paged<VideoCard>
    private var failure: APIError?
    private(set) var requestedPages: [Int] = []

    init(page: Paged<VideoCard>, failure: APIError? = nil) {
        self.page = page
        self.failure = failure
    }

    func set(page: Paged<VideoCard>, failure: APIError? = nil) {
        self.page = page
        self.failure = failure
    }

    func feed(page: Int, size: Int) async throws -> Paged<VideoCard> {
        requestedPages.append(page)
        if let failure { throw failure }
        return self.page
    }

    func playback(id: Int, ep: Int) async throws -> PlayInfo {
        PlayInfo(
            id: id,
            epNum: ep,
            title: "第\(ep)集",
            duration: 0,
            videoURL: "https://example.com/\(id)/\(ep).m3u8",
            videoURLHEVC: nil,
            cdn: nil
        )
    }
}

private func makePage(ids: [Int], page: Int, pages: Int) -> Paged<VideoCard> {
    let cards = ids.map { id in
        VideoCard(id: id, title: "视频 \(id)", cover: "https://example.com/\(id).jpg", episodeCount: 3)
    }
    return Paged(
        items: cards,
        pagination: Pagination(page: page, pages: pages, size: 10, total: pages * 10)
    )
}

@MainActor
struct HomeViewModelTests {
    @Test
    func firstPageAndLoadMoreDeduplicates() async {
        let repo = StubVideoRepository(page: makePage(ids: [1, 2, 3], page: 1, pages: 2))
        let model = HomeViewModel(videos: repo)

        await model.loadInitial()
        #expect(model.items.map(\.id) == [1, 2, 3])
        #expect(model.hasMore)

        await repo.set(page: makePage(ids: [3, 4, 5], page: 2, pages: 2))
        await model.loadMoreIfNeeded(currentID: 3)

        #expect(model.items.map(\.id) == [1, 2, 3, 4, 5])
        #expect(model.page == 2)
        #expect(!model.hasMore)
    }

    @Test
    func loadsThreePagesWithoutDuplicates() async {
        let repo = StubVideoRepository(page: makePage(ids: Array(1...10), page: 1, pages: 3))
        let model = HomeViewModel(videos: repo)

        await model.loadInitial()
        await repo.set(page: makePage(ids: Array(11...20), page: 2, pages: 3))
        await model.loadMoreIfNeeded(currentID: 10)
        await repo.set(page: makePage(ids: Array(19...30), page: 3, pages: 3))
        await model.loadMoreIfNeeded(currentID: 20)

        #expect(model.items.count == 30)
        #expect(Set(model.items.map(\.id)).count == 30)
        #expect(model.items.last?.id == 30)
        #expect(!model.hasMore)
    }

    @Test
    func doesNotLoadWhenCurrentItemIsFarFromEnd() async {
        let ids = Array(1...10)
        let repo = StubVideoRepository(page: makePage(ids: ids, page: 1, pages: 2))
        let model = HomeViewModel(videos: repo)

        await model.loadInitial()
        await model.loadMoreIfNeeded(currentID: 1)

        let requested = await repo.requestedPages
        #expect(requested == [1])
    }

    @Test
    func errorKeepsExistingItemsAndRetryRecovers() async {
        let repo = StubVideoRepository(page: makePage(ids: [1, 2], page: 1, pages: 2))
        let model = HomeViewModel(videos: repo)

        await model.loadInitial()
        await repo.set(page: makePage(ids: [3, 4], page: 2, pages: 2), failure: .network("离线"))
        await model.loadMoreIfNeeded(currentID: 2)

        #expect(model.items.map(\.id) == [1, 2])
        #expect(model.error != nil)

        await repo.set(page: makePage(ids: [3, 4], page: 2, pages: 2))
        await model.retry()

        #expect(model.items.map(\.id) == [1, 2, 3, 4])
        #expect(model.error == nil)
    }
}

@MainActor
struct FeedViewModelTests {
    @Test
    func loadsNextPageAndDeduplicates() async {
        let cards = (1...3).map { VideoCard(id: $0, title: "视频 \($0)", episodeCount: 2) }
        let context = FeedContext(cards: cards, index: 1, title: "测试", page: 1, pages: 2)
        let repo = StubVideoRepository(page: makePage(ids: [3, 4, 5], page: 2, pages: 2))
        let model = FeedViewModel(context: context, videos: repo)

        #expect(model.index == 1)
        await model.loadMoreIfNeeded(at: 2)

        #expect(model.cards.map(\.id) == [1, 2, 3, 4, 5])
        #expect(model.page == 2)
        #expect(!model.hasMore)
    }

    @Test
    func clampsContextIndexAndEpisodeTotal() {
        let cards = [VideoCard(id: 1, title: "一", episodeCount: 0)]
        let context = FeedContext(cards: cards, index: 9, title: "测试")
        let model = FeedViewModel(context: context, videos: StubVideoRepository(page: makePage(ids: [1], page: 1, pages: 1)))

        #expect(model.index == 0)
        #expect(model.cards[0].episodeTotal == 1)
        #expect(PlayerState.clock(65) == "01:05")
        #expect(PlayerState.clock(3661) == "1:01:01")
    }
}
