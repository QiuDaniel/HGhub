import Foundation
import Observation

/// 首页分页模型：首屏、加载更多、去重、错误重试。
@MainActor
@Observable
final class HomeViewModel {
    private let videos: VideoRepository

    private(set) var items: [VideoCard] = []
    private(set) var page = 0
    private(set) var pages = 1
    private(set) var total = 0
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var error: String?

    private var seen = Set<Int>()

    init(videos: VideoRepository) {
        self.videos = videos
    }

    var hasMore: Bool { page < pages }
    var isEmpty: Bool { items.isEmpty }

    func loadInitial() async {
        guard items.isEmpty, !isLoading else { return }
        await load(page: 1, replace: true)
    }

    func refresh() async {
        guard !isLoading, !isLoadingMore else { return }
        page = 0
        pages = 1
        total = 0
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
            let response = try await videos.feed(page: nextPage, size: 10)
            guard !Task.isCancelled else { return }

            if replace {
                items = []
                seen.removeAll()
            }

            for card in response.items where seen.insert(card.id).inserted {
                items.append(card)
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
