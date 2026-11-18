import Foundation
import Testing
@testable import HGHub

private final class PostBundleToken {}

private func postFixture(_ name: String) throws -> Data {
    let bundle = Bundle(for: PostBundleToken.self)
    guard let url = bundle.url(forResource: name, withExtension: "json") else {
        throw APIError.business("缺少 fixture \(name)")
    }
    return try Data(contentsOf: url)
}

struct PostDecodingTests {
    @Test
    func decodesPostListFixture() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let page = try decoder.decode(Paged<Post>.self, from: postFixture("posts_page1"))

        #expect(page.items.count == 10)
        #expect(page.pagination.pages == 80)
        #expect(page.pagination.total == 791)
        #expect(page.items.first?.id == 65)
        #expect(page.items.first?.displayTitle.isEmpty == false)
    }

    @Test
    func decodesPostDetailAndCommentsFixture() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let post = try decoder.decode(Post.self, from: postFixture("post_detail_67"))
        #expect(post.id == 67)
        #expect(post.content?.contains("data-src") == true)
        #expect(post.counts?.like != nil)
        #expect(post.author?.name?.isEmpty == false)

        let comments = try decoder.decode(CommentPage.self, from: postFixture("post_comments_67"))
        #expect(comments.items.count == 2)
        #expect(comments.pagination.total == 2)
        #expect(comments.items.first?.displayText.isEmpty == false)
    }
}

struct HTMLSanitizerTests {
    @Test
    func removesScriptsEventsAndJavascriptURLs() throws {
        let html = """
        <p onclick="steal()">正文</p>
        <script>alert(1)</script>
        <img src="/placeholder.png" data-src="https://pic.example.com/a.jpg" srcset="x">
        <a href="javascript:alert(1)">bad</a>
        <a href="/tag/1">tag</a>
        """
        let clean = try HTMLSanitizer.sanitize(
            html,
            baseURL: URL(string: "https://huangguoai.com")!
        )

        #expect(!clean.contains("script"))
        #expect(!clean.contains("onclick"))
        #expect(!clean.contains("javascript:"))
        #expect(clean.contains("https://pic.example.com/a.jpg"))
        #expect(clean.contains("https://huangguoai.com/tag/1"))
        #expect(!clean.contains("srcset"))
    }
}

private actor PostRepositoryStub: PostRepository {
    var pages: [Int: Paged<Post>] = [:]
    var detail: Post?
    var likeError: APIError?
    private(set) var likeCalls: [(Int, Bool)] = []

    func setPages(_ pages: [Int: Paged<Post>]) { self.pages = pages }
    func setDetail(_ post: Post?) { detail = post }
    func setLikeError(_ error: APIError?) { likeError = error }

    func posts(page: Int, size: Int) async throws -> Paged<Post> {
        pages[page] ?? Paged(
            items: [],
            pagination: Pagination(page: page, pages: 1, size: size, total: 0)
        )
    }

    func post(id: Int) async throws -> Post {
        if let detail { return detail }
        throw APIError.business("missing detail")
    }

    func comments(id: Int, page: Int, size: Int) async throws -> CommentPage {
        CommentPage(ep: 1, items: [], pagination: Pagination(page: page, pages: 1, size: size, total: 0))
    }

    func sendComment(id: Int, text: String, replyID: Int?) async throws {}

    func like(id: Int, on: Bool) async throws {
        likeCalls.append((id, on))
        if let likeError { throw likeError }
    }

    func collect(id: Int, on: Bool) async throws {}
}

@MainActor
struct PostDetailViewModelTests {
    private func makePost(id: Int, like: Int) -> Post {
        Post(
            id: id,
            title: "帖子",
            desc: nil,
            content: "<p>正文</p>",
            cover: nil,
            tags: nil,
            hot: 1,
            videoURL: nil,
            videoID: nil,
            author: nil,
            counts: Post.Counts(like: like, comment: 0, collect: 0, share: 0, hot: 1),
            interaction: nil,
            createdAt: nil,
            publishTime: nil
        )
    }

    @Test
    func likeIsOptimisticAndRollsBackOnFailure() async {
        let stub = PostRepositoryStub()
        await stub.setDetail(makePost(id: 7, like: 10))
        let model = PostDetailViewModel(postID: 7, repository: stub)

        await model.load()
        #expect(model.likeCount == 10)

        let ok = await model.toggleLike()
        #expect(ok == .ok)
        #expect(model.liked)
        #expect(model.likeCount == 11)

        await stub.setLikeError(.network("离线"))
        let failed = await model.toggleLike()
        #expect(failed == .failed("网络错误：离线"))
        #expect(model.liked)
        #expect(model.likeCount == 11)
    }
}

@MainActor
struct PostsViewModelTests {
    private func makePage(ids: [Int], page: Int, pages: Int) -> Paged<Post> {
        let posts = ids.map {
            Post(
                id: $0,
                title: "帖子 \($0)",
                desc: nil,
                content: nil,
                cover: nil,
                tags: nil,
                hot: $0 * 10,
                videoURL: nil,
                videoID: nil,
                author: nil,
                counts: nil,
                interaction: nil,
                createdAt: nil,
                publishTime: nil
            )
        }
        return Paged(
            items: posts,
            pagination: Pagination(page: page, pages: pages, size: 10, total: pages * 10)
        )
    }

    @Test
    func loadsAndPaginatesPosts() async {
        let stub = PostRepositoryStub()
        await stub.setPages([
            1: makePage(ids: [1, 2, 3], page: 1, pages: 2),
            2: makePage(ids: [3, 4], page: 2, pages: 2),
        ])
        let model = PostsViewModel(repository: stub)

        await model.loadInitial()
        #expect(model.items.map(\.id) == [1, 2, 3])
        #expect(model.hasMore)

        await model.loadMoreIfNeeded(currentID: 3)
        #expect(model.items.map(\.id) == [1, 2, 3, 4])
        #expect(!model.hasMore)
    }
}
