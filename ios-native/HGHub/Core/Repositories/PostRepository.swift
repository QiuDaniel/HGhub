import Foundation

protocol PostRepository: Sendable {
    func posts(page: Int, size: Int) async throws -> Paged<Post>
    func post(id: Int) async throws -> Post
    func comments(id: Int, page: Int, size: Int) async throws -> CommentPage
    func sendComment(id: Int, text: String, replyID: Int?) async throws
    func like(id: Int, on: Bool) async throws
    func collect(id: Int, on: Bool) async throws
}

struct LivePostRepository: PostRepository {
    let api: APIClient

    private struct CommentRequest: Encodable {
        let text: String
        let replyId: Int?

        enum CodingKeys: String, CodingKey {
            case text
            case replyId = "reply_id"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(replyId, forKey: .replyId)
        }
    }

    func posts(page: Int, size: Int) async throws -> Paged<Post> {
        try await api.get("/api/posts?page=\(page)&size=\(size)", as: Paged<Post>.self)
    }

    func post(id: Int) async throws -> Post {
        try await api.get("/api/posts/\(id)", as: Post.self)
    }

    func comments(id: Int, page: Int, size: Int) async throws -> CommentPage {
        try await api.get(
            "/api/posts/\(id)/comments?page=\(page)&size=\(size)",
            as: CommentPage.self
        )
    }

    func sendComment(id: Int, text: String, replyID: Int?) async throws {
        try await api.postAction(
            "/api/posts/\(id)/comments",
            body: CommentRequest(text: text, replyId: replyID)
        )
    }

    func like(id: Int, on: Bool) async throws {
        let path = "/api/posts/\(id)/like"
        if on {
            try await api.postAction(path)
        } else {
            try await api.deleteAction(path)
        }
    }

    func collect(id: Int, on: Bool) async throws {
        let path = "/api/posts/\(id)/collect"
        if on {
            try await api.postAction(path)
        } else {
            try await api.deleteAction(path)
        }
    }
}
