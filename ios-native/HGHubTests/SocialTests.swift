import Foundation
import Testing
@testable import HGHub

private actor FakeSocialRepository: VideoSocialRepository {
    var likeError: APIError?
    var commentPages: [Int: CommentPage] = [:]
    private(set) var likeCalls: [(Int, Int, Bool)] = []
    private(set) var collectCalls: [(Int, Bool)] = []
    private(set) var followCalls: [(Int, Bool)] = []
    private(set) var sentComments: [(Int, Int, String, Int?)] = []

    func setLikeError(_ error: APIError?) {
        likeError = error
    }

    func setCommentPages(_ pages: [Int: CommentPage]) {
        commentPages = pages
    }

    func detail(id: Int) async throws -> VideoDetail {
        throw APIError.business("测试没有详情")
    }

    func comments(id: Int, ep: Int, page: Int, size: Int) async throws -> CommentPage {
        guard let value = commentPages[page] else {
            return CommentPage(
                ep: ep,
                items: [],
                pagination: Pagination(page: page, pages: 1, size: size, total: 0)
            )
        }
        return value
    }

    func sendComment(id: Int, ep: Int, text: String, replyID: Int?) async throws {
        sentComments.append((id, ep, text, replyID))
    }

    func like(id: Int, ep: Int, on: Bool) async throws {
        likeCalls.append((id, ep, on))
        if let likeError { throw likeError }
    }

    func collect(id: Int, on: Bool) async throws {
        collectCalls.append((id, on))
    }

    func follow(uid: Int, on: Bool) async throws {
        followCalls.append((uid, on))
    }
}

private final class SocialBundleToken {}

private func socialFixture(_ name: String) throws -> Data {
    let bundle = Bundle(for: SocialBundleToken.self)
    guard let url = bundle.url(forResource: name, withExtension: "json") else {
        throw APIError.business("缺少 fixture \(name)")
    }
    return try Data(contentsOf: url)
}

struct SocialDecodingTests {
    @Test
    func decodesRealDetailFixture() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let detail = try decoder.decode(VideoDetail.self, from: socialFixture("video_detail_117"))

        #expect(detail.id == 117)
        #expect(detail.displayTitle == "高三爱情故事")
        #expect(detail.episodes?.count == 42)
        #expect(detail.episodeTotal == 42)
        #expect(detail.counts?.like == 421_410)
        #expect(detail.author?.name == "黄果官方")
        #expect(detail.author?.isFollowing == false)
        #expect(detail.tags?.contains("校园") == true)
    }

    @Test
    func decodesRealCommentsFixture() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let page = try decoder.decode(CommentPage.self, from: socialFixture("comments_117_3"))

        #expect(page.ep == 3)
        #expect(page.items.count == 5)
        #expect(page.pagination.total == 54)
        #expect(page.pagination.pages == 11)
        #expect(page.items.first?.displayText.isEmpty == false)
        #expect(page.items.first?.replies.count == 1)
        #expect(page.items.first?.displayName.isEmpty == false)
    }
}

@MainActor
struct InteractionModelTests {
    private func makeLibrary() throws -> LocalLibrary {
        let name = "test_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let suite = try #require(UserDefaults(suiteName: name))
        return LocalLibrary(suite: suite, namespace: name)
    }

    @Test
    func optimisticLikeCommitsAndPersistsLocally() async throws {
        let library = try makeLibrary()
        let fake = FakeSocialRepository()
        let card = VideoCard(id: 1, title: "测试", likeCount: 10)
        let model = FeedInteractionModel(card: card, ep: 2, social: fake, library: library)

        let outcome = await model.toggleLike()

        #expect(outcome == .ok)
        #expect(model.liked)
        #expect(model.likeCount == 11)
        #expect(library.isLiked(1))
        let calls = await fake.likeCalls
        #expect(calls.count == 1)
        #expect(calls.first?.0 == 1)
        #expect(calls.first?.1 == 2)
        #expect(calls.first?.2 == true)
    }

    @Test
    func failedLikeRollsBackAndDoesNotPersist() async throws {
        let library = try makeLibrary()
        let fake = FakeSocialRepository()
        await fake.setLikeError(.network("离线"))
        let card = VideoCard(id: 2, title: "测试", likeCount: 10)
        let model = FeedInteractionModel(card: card, ep: 1, social: fake, library: library)

        let outcome = await model.toggleLike()

        #expect(outcome == .failed("网络错误：离线"))
        #expect(!model.liked)
        #expect(model.likeCount == 10)
        #expect(!library.isLiked(2))
    }

    @Test
    func collectAndFollowCommitToLocalLibrary() async throws {
        let library = try makeLibrary()
        let fake = FakeSocialRepository()
        let card = VideoCard(
            id: 4,
            title: "测试",
            likeCount: 0,
            author: Author(id: 9, name: "作者", avatar: nil, followers: 12)
        )
        let model = FeedInteractionModel(card: card, ep: 1, social: fake, library: library)

        let collectOutcome = await model.toggleCollect()
        #expect(collectOutcome == .ok)
        #expect(model.collected)
        #expect(model.collectCount == 1)
        #expect(library.isFavorite(4))

        let followOutcome = await model.toggleFollow()
        #expect(followOutcome == .ok)
        #expect(model.following)
        #expect(library.isFollowing(9))

        let collects = await fake.collectCalls
        let follows = await fake.followCalls
        #expect(collects.first?.0 == 4)
        #expect(collects.first?.1 == true)
        #expect(follows.first?.0 == 9)
        #expect(follows.first?.1 == true)
    }

    @Test
    func unauthorizedLikeReturnsUnauthorizedAndRollsBack() async throws {
        let library = try makeLibrary()
        let fake = FakeSocialRepository()
        await fake.setLikeError(.unauthorized)
        let card = VideoCard(id: 3, title: "测试", likeCount: 1)
        let model = FeedInteractionModel(card: card, ep: 1, social: fake, library: library)

        let outcome = await model.toggleLike()
        #expect(outcome == .unauthorized)
        #expect(!model.liked)
        #expect(model.likeCount == 1)
    }
}

@MainActor
struct CommentsViewModelTests {
    @Test
    func paginationDeduplicatesSameComments() async throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let fixture = try decoder.decode(CommentPage.self, from: socialFixture("comments_117_3"))
        let page1 = CommentPage(
            ep: 3,
            items: fixture.items,
            pagination: Pagination(page: 1, pages: 2, size: 5, total: 54)
        )
        let page2 = CommentPage(
            ep: 3,
            items: fixture.items,
            pagination: Pagination(page: 2, pages: 2, size: 5, total: 54)
        )
        let fake = FakeSocialRepository()
        await fake.setCommentPages([1: page1, 2: page2])
        let model = CommentsViewModel(videoID: 117, ep: 3, social: fake, pageSize: 5)

        await model.loadInitial()
        #expect(model.items.count == 5)
        #expect(model.pages == 2)
        #expect(model.hasMore)

        await model.loadMore()
        #expect(model.items.count == 5)
        #expect(model.page == 2)
        #expect(!model.hasMore)
    }
}
