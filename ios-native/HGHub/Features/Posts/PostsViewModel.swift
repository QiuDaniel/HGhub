import Foundation
import Observation

@MainActor
@Observable
final class PostsViewModel {
    private let repository: PostRepository
    private let pageSize = 20

    private(set) var items: [Post] = []
    private(set) var page = 0
    private(set) var pages = 1
    private(set) var total = 0
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var error: String?

    private var seen = Set<Int>()

    init(repository: PostRepository) {
        self.repository = repository
    }

    var isEmpty: Bool { items.isEmpty }
    var hasMore: Bool { page < pages }

    func loadInitial() async {
        guard items.isEmpty, !isLoading else { return }
        await load(page: 1, replace: true)
    }

    func loadMoreIfNeeded(currentID: Int) async {
        guard !isLoading, !isLoadingMore, hasMore else { return }
        guard let index = items.firstIndex(where: { $0.id == currentID }) else { return }
        guard index >= items.count - 3 else { return }
        await load(page: page + 1, replace: false)
    }

    func retry() async {
        if items.isEmpty {
            await load(page: 1, replace: true)
        } else if hasMore {
            await load(page: page + 1, replace: false)
        }
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
            let response = try await repository.posts(page: nextPage, size: pageSize)
            guard !Task.isCancelled else { return }
            if replace {
                items = []
                seen.removeAll()
            }
            for post in response.items where seen.insert(post.id).inserted {
                items.append(post)
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
