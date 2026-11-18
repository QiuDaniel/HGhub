import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    private let discovery: VideoDiscoveryRepository
    private let library: LocalLibrary
    private let pageSize: Int

    private(set) var submitted = ""
    private(set) var items: [VideoCard] = []
    private(set) var page = 0
    private(set) var pages = 1
    private(set) var total = 0
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var error: String?

    private var seen = Set<Int>()
    private var loadGeneration = 0

    init(discovery: VideoDiscoveryRepository, library: LocalLibrary, pageSize: Int = 10) {
        self.discovery = discovery
        self.library = library
        self.pageSize = pageSize
    }

    var isSearching: Bool { !submitted.isEmpty }
    var hasMore: Bool { page < pages }

    func submit(_ raw: String) async {
        let keyword = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        submitted = keyword
        library.addSearch(keyword)
        page = 0
        pages = 1
        total = 0
        items = []
        seen.removeAll()
        loadGeneration += 1
        await load(page: 1, replace: true, generation: loadGeneration)
    }

    func retry() async {
        guard isSearching else { return }
        if items.isEmpty {
            await load(page: 1, replace: true, generation: loadGeneration)
        } else if hasMore {
            await load(page: page + 1, replace: false, generation: loadGeneration)
        }
    }

    func loadMoreIfNeeded(currentID: Int) async {
        guard !isLoading, !isLoadingMore, hasMore, isSearching else { return }
        guard let index = items.firstIndex(where: { $0.id == currentID }) else { return }
        guard index >= items.count - 3 else { return }
        await load(page: page + 1, replace: false, generation: loadGeneration)
    }

    func clear() {
        submitted = ""
        items = []
        page = 0
        pages = 1
        total = 0
        error = nil
        seen.removeAll()
        loadGeneration += 1
    }

    private func load(page nextPage: Int, replace: Bool, generation: Int) async {
        guard nextPage > 0, isSearching else { return }
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
            let response = try await discovery.search(
                query: submitted,
                page: nextPage,
                size: pageSize
            )
            guard !Task.isCancelled, generation == loadGeneration else { return }

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
