import Foundation
import Observation

@MainActor
@Observable
final class CommentsViewModel {
    let videoID: Int
    let ep: Int
    private let social: VideoSocialRepository
    private let pageSize: Int

    private(set) var items: [Comment] = []
    private(set) var page = 0
    private(set) var pages = 1
    private(set) var total = 0
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var error: String?

    private var seen = Set<Int>()

    init(videoID: Int, ep: Int, social: VideoSocialRepository, pageSize: Int = 20) {
        self.videoID = videoID
        self.ep = ep
        self.social = social
        self.pageSize = pageSize
    }

    var isEmpty: Bool { items.isEmpty }
    var hasMore: Bool { page < pages }

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

    @discardableResult
    func send(text: String, replyID: Int? = nil) async throws -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        try await social.sendComment(id: videoID, ep: ep, text: trimmed, replyID: replyID)
        await load(page: 1, replace: true)
        return true
    }

    private func load(page nextPage: Int, replace: Bool) async {
        guard nextPage > 0 else { return }
        if replace {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        error = nil
        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            let response = try await social.comments(
                id: videoID,
                ep: ep,
                page: nextPage,
                size: pageSize
            )
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
