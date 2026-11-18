import Foundation
import Testing
@testable import HGHub

private actor DiscoveryStub: VideoDiscoveryRepository {
    var searchPages: [Int: Paged<VideoCard>] = [:]
    var categoryPages: [String: [Int: Paged<VideoCard>]] = [:]
    var rankPage = RankPage(type: "hot", items: [])
    private(set) var searchCalls: [(String, Int)] = []
    private(set) var categoryCalls: [(String, Int)] = []

    func setSearchPages(_ pages: [Int: Paged<VideoCard>]) {
        searchPages = pages
    }

    func setCategoryPages(_ pages: [String: [Int: Paged<VideoCard>]]) {
        categoryPages = pages
    }

    func setRankPage(_ page: RankPage) {
        rankPage = page
    }

    func category(cate: String, page: Int, size: Int) async throws -> Paged<VideoCard> {
        categoryCalls.append((cate, page))
        return categoryPages[cate]?[page] ?? makePage(ids: [], page: page, pages: 1)
    }

    func search(query: String, page: Int, size: Int) async throws -> Paged<VideoCard> {
        searchCalls.append((query, page))
        return searchPages[page] ?? makePage(ids: [], page: page, pages: 1)
    }

    func ranks(kind: RankKind) async throws -> RankPage {
        rankPage
    }
}

private func makePage(ids: [Int], page: Int, pages: Int) -> Paged<VideoCard> {
    Paged(
        items: ids.map { VideoCard(id: $0, title: "视频 \($0)", cover: "https://example.com/\($0).jpg", episodeCount: 3) },
        pagination: Pagination(page: page, pages: pages, size: 10, total: max(pages, 1) * 10)
    )
}

private final class DiscoveryBundleToken {}

private func discoveryFixture(_ name: String) throws -> Data {
    let bundle = Bundle(for: DiscoveryBundleToken.self)
    guard let url = bundle.url(forResource: name, withExtension: "json") else {
        throw APIError.business("缺少 fixture \(name)")
    }
    return try Data(contentsOf: url)
}

struct RankDecodingTests {
    @Test
    func decodesRealRankFixture() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let page = try decoder.decode(RankPage.self, from: discoveryFixture("rank_hot"))

        #expect(page.type == "hot")
        #expect(page.items.count == 20)
        #expect(page.items.first?.rank == 1)
        #expect(page.items.first?.videoID == 2833)
        #expect(page.items.first?.metricValue == 6019)
        #expect(page.items.first?.card.id == 2833)
    }
}

@MainActor
struct SearchViewModelTests {
    private func makeLibrary() throws -> LocalLibrary {
        let name = "test_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let suite = try #require(UserDefaults(suiteName: name))
        return LocalLibrary(suite: suite, namespace: name)
    }

    @Test
    func emptyQueryDoesNotRequestAndSubmitStoresHistory() async throws {
        let library = try makeLibrary()
        let stub = DiscoveryStub()
        await stub.setSearchPages([
            1: makePage(ids: [1, 2], page: 1, pages: 2),
            2: makePage(ids: [2, 3], page: 2, pages: 2),
        ])
        let model = SearchViewModel(discovery: stub, library: library)

        await model.submit("   ")
        let emptyCalls = await stub.searchCalls
        #expect(emptyCalls.isEmpty)

        await model.submit("  高三  ")
        #expect(model.submitted == "高三")
        #expect(model.items.map(\.id) == [1, 2])
        #expect(library.searchHistory.first == "高三")

        await model.loadMoreIfNeeded(currentID: 2)
        #expect(model.items.map(\.id) == [1, 2, 3])
        #expect(model.page == 2)
        let calls = await stub.searchCalls
        #expect(calls.count == 2)
        #expect(calls.first?.0 == "高三")
    }

    @Test
    func clearResetsResults() async throws {
        let library = try makeLibrary()
        let stub = DiscoveryStub()
        await stub.setSearchPages([1: makePage(ids: [1], page: 1, pages: 1)])
        let model = SearchViewModel(discovery: stub, library: library)

        await model.submit("都市")
        #expect(!model.items.isEmpty)
        model.clear()
        #expect(model.items.isEmpty)
        #expect(!model.isSearching)
    }
}

private struct EmptyVideoRepository: VideoRepository {
    func feed(page: Int, size: Int) async throws -> Paged<VideoCard> {
        makePage(ids: [], page: page, pages: 1)
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

@MainActor
struct FeedSourcePagingTests {
    @Test
    func searchFeedLoadsNextPageFromSearchAPI() async {
        let stub = DiscoveryStub()
        await stub.setSearchPages([2: makePage(ids: [2], page: 2, pages: 2)])
        let context = FeedContext(
            cards: [VideoCard(id: 1, title: "一")],
            index: 0,
            title: "搜索 · 高三",
            source: "search",
            page: 1,
            pages: 2,
            query: "高三"
        )
        let model = FeedViewModel(
            context: context,
            videos: EmptyVideoRepository(),
            discovery: stub
        )

        await model.loadMoreIfNeeded(at: 0)

        #expect(model.cards.map(\.id) == [1, 2])
        let calls = await stub.searchCalls
        #expect(calls.count == 1)
        #expect(calls.first?.0 == "高三")
        #expect(calls.first?.1 == 2)
    }

    @Test
    func channelFeedLoadsNextPageFromCategoryAPI() async {
        let stub = DiscoveryStub()
        await stub.setCategoryPages([
            "24": [2: makePage(ids: [2], page: 2, pages: 2)],
        ])
        let context = FeedContext(
            cards: [VideoCard(id: 1, title: "一")],
            index: 0,
            title: "AI成人短剧",
            source: "channel",
            page: 1,
            pages: 2,
            cate: "24"
        )
        let model = FeedViewModel(
            context: context,
            videos: EmptyVideoRepository(),
            discovery: stub
        )

        await model.loadMoreIfNeeded(at: 0)

        #expect(model.cards.map(\.id) == [1, 2])
        let calls = await stub.categoryCalls
        #expect(calls.first?.0 == "24")
        #expect(calls.first?.1 == 2)
    }
}

@MainActor
struct ChannelViewModelTests {
    @Test
    func loadsPagesAndDeduplicates() async throws {
        let stub = DiscoveryStub()
        await stub.setCategoryPages([
            "24": [
                1: makePage(ids: [1, 2], page: 1, pages: 2),
                2: makePage(ids: [2, 3], page: 2, pages: 2),
            ],
        ])
        let channel = ChannelInfo.all.first { $0.cate == "24" }!
        let model = ChannelViewModel(channel: channel, discovery: stub)

        await model.loadInitial()
        #expect(model.items.map(\.id) == [1, 2])
        #expect(model.hasMore)

        await model.loadMoreIfNeeded(currentID: 2)
        #expect(model.items.map(\.id) == [1, 2, 3])
        #expect(model.page == 2)
        #expect(!model.hasMore)
    }
}

@MainActor
struct CategoryViewModelTests {
    @Test
    func hidesEmptyChannels() async throws {
        let stub = DiscoveryStub()
        await stub.setCategoryPages([
            "24": [1: makePage(ids: [1, 2], page: 1, pages: 3)],
            "25": [1: makePage(ids: [3], page: 1, pages: 1)],
        ])
        let model = CategoryViewModel(discovery: stub)

        await model.load()

        #expect(model.rows.count == 2)
        #expect(model.rows.map(\.channel.cate) == ["24", "25"])
        #expect(model.rows.first?.pages == 3)
        #expect(model.isLoading == false)
    }
}
