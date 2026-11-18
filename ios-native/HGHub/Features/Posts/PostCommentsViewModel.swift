import Foundation
import Observation

@MainActor
@Observable
final class PostCommentsViewModel {
    private let repository: PostRepository
    let postID: Int
    private let pageSize = 20

    private(set) var items: [Comment] = []
    private(set) var page = 0
    private(set) var pages = 1
    private(set) var total = 0
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var error: String?

    private var seen = Set<Int>()

    init(postID: Int, repository: PostRepository) {
        self.postID = postID
        self.repository = repository
    }

    var hasMore: Bool { page < pages }
    var isEmpty: Bool { items.isEmpty }

    func loadInitial() async {
        guard !isLoading else { return }
        await load(page: 1, replace: true)
    }

    func loadMoreIfNeeded(currentID: Int) async {
        guard !isLoading, !isLoadingMore, hasMore else { return }
        guard let index = items.firstIndex(where: { $0.id == currentID }) else { return }
        guard index >= items.count - 2 else { return }
        await load(page: page + 1, replace: false)
    }

    func loadMore() async {
        guard hasMore else { return }
        await load(page: page + 1, replace: false)
    }

    func send(text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await repository.sendComment(id: postID, text: trimmed, replyID: nil)
        await load(page: 1, replace: true)
    }

    private func load(page nextPage: Int, replace: Bool) async {
        if replace { isLoading = true } else { isLoadingMore = true }
        error = nil
        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            let response = try await repository.comments(id: postID, page: nextPage, size: pageSize)
            guard !Task.isCancelled else { return }
            if replace {
                items = []
                seen.removeAll()
            }
            for comment in response.items where seen.insert(comment.id).inserted {
                items.append(comment)
            }
            page = response.pagination.page
            pages = max(response.pagination.pages, page)
            total = response.pagination.total
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription
        }
    }
}
