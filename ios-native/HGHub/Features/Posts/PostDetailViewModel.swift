import Foundation
import Observation

@MainActor
@Observable
final class PostDetailViewModel {
    let postID: Int
    private let repository: PostRepository

    private(set) var post: Post?
    private(set) var isLoading = false
    var error: String?

    var liked = false
    var collected = false
    var likeCount = 0
    var collectCount = 0
    var commentCount = 0

    init(postID: Int, repository: PostRepository) {
        self.postID = postID
        self.repository = repository
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let value = try await repository.post(id: postID)
            post = value
            apply(value)
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleLike() async -> InteractionOutcome {
        let next = !liked
        let previous = liked
        let previousCount = likeCount
        liked = next
        likeCount = max(0, likeCount + (next ? 1 : -1))

        do {
            try await repository.like(id: postID, on: next)
            return .ok
        } catch let error as APIError {
            liked = previous
            likeCount = previousCount
            if case .unauthorized = error { return .unauthorized }
            return .failed(error.localizedDescription)
        } catch {
            liked = previous
            likeCount = previousCount
            return .failed(error.localizedDescription)
        }
    }

    func toggleCollect() async -> InteractionOutcome {
        let next = !collected
        let previous = collected
        let previousCount = collectCount
        collected = next
        collectCount = max(0, collectCount + (next ? 1 : -1))

        do {
            try await repository.collect(id: postID, on: next)
            return .ok
        } catch let error as APIError {
            collected = previous
            collectCount = previousCount
            if case .unauthorized = error { return .unauthorized }
            return .failed(error.localizedDescription)
        } catch {
            collected = previous
            collectCount = previousCount
            return .failed(error.localizedDescription)
        }
    }

    func noteCommentSent() {
        commentCount += 1
    }

    private func apply(_ post: Post) {
        if let counts = post.counts {
            likeCount = max(counts.like ?? 0, 0)
            collectCount = max(counts.collect ?? 0, 0)
            commentCount = max(counts.comment ?? 0, 0)
        }
        if let interaction = post.interaction {
            liked = interaction.liked ?? false
            collected = interaction.collected ?? false
        }
    }
}
