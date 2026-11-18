import Foundation

protocol VideoSocialRepository: Sendable {
    func detail(id: Int) async throws -> VideoDetail
    func comments(id: Int, ep: Int, page: Int, size: Int) async throws -> CommentPage
    func sendComment(id: Int, ep: Int, text: String, replyID: Int?) async throws
    func like(id: Int, ep: Int, on: Bool) async throws
    func collect(id: Int, on: Bool) async throws
    func follow(uid: Int, on: Bool) async throws
}

struct LiveVideoSocialRepository: VideoSocialRepository {
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

    func detail(id: Int) async throws -> VideoDetail {
        try await api.get("/api/videos/\(id)", as: VideoDetail.self)
    }

    func comments(id: Int, ep: Int, page: Int, size: Int) async throws -> CommentPage {
        try await api.get(
            "/api/videos/\(id)/comments?ep=\(ep)&page=\(page)&size=\(size)",
            as: CommentPage.self
        )
    }

    func sendComment(id: Int, ep: Int, text: String, replyID: Int?) async throws {
        if let replyID, replyID > 0 {
            try await api.postAction(
                "/api/videos/\(id)/comments",
                body: CommentRequest(text: text, replyId: replyID)
            )
        } else {
            try await api.postAction(
                "/api/videos/\(id)/comments?ep=\(ep)",
                body: CommentRequest(text: text, replyId: nil)
            )
        }
    }

    func like(id: Int, ep: Int, on: Bool) async throws {
        let path = "/api/videos/\(id)/like?ep=\(ep)"
        if on {
            try await api.postAction(path)
        } else {
            try await api.deleteAction(path)
        }
    }

    func collect(id: Int, on: Bool) async throws {
        let path = "/api/videos/\(id)/collect"
        if on {
            try await api.postAction(path)
        } else {
            try await api.deleteAction(path)
        }
    }

    func follow(uid: Int, on: Bool) async throws {
        let path = "/api/users/\(uid)/follow"
        if on {
            try await api.postAction(path)
        } else {
            try await api.deleteAction(path)
        }
    }
}
