import Foundation
import Observation

struct CategoryRow: Identifiable, Sendable {
    let channel: ChannelInfo
    let items: [VideoCard]
    let pages: Int

    var id: String { channel.cate }
}

@MainActor
@Observable
final class CategoryViewModel {
    private let discovery: VideoDiscoveryRepository

    private(set) var rows: [CategoryRow] = []
    private(set) var isLoading = true
    var error: String?

    init(discovery: VideoDiscoveryRepository) {
        self.discovery = discovery
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let discovery = self.discovery
        let results = await withTaskGroup(
            of: (ChannelInfo, Paged<VideoCard>?).self,
            returning: [(ChannelInfo, Paged<VideoCard>?)].self
        ) { group in
            for channel in ChannelInfo.all {
                group.addTask {
                    let page = try? await discovery.category(
                        cate: channel.cate,
                        page: 1,
                        size: 10
                    )
                    return (channel, page)
                }
            }
            var values: [(ChannelInfo, Paged<VideoCard>?)] = []
            for await value in group {
                values.append(value)
            }
            return values
        }

        let byCate = Dictionary(uniqueKeysWithValues: results.map { ($0.0.cate, $0.1) })
        // 空频道（如 26/27）首屏没有任何内容就隐藏；上游恢复后会自动出现。
        rows = ChannelInfo.all.compactMap { channel in
            guard let page = byCate[channel.cate] ?? nil, !page.items.isEmpty else {
                return nil
            }
            return CategoryRow(
                channel: channel,
                items: page.items,
                pages: max(page.pagination.pages, 1)
            )
        }
    }

    func refresh() async {
        await load()
    }
}

@MainActor
@Observable
final class ChannelViewModel {
    let channel: ChannelInfo
    private let discovery: VideoDiscoveryRepository
    private let pageSize = 10

    private(set) var items: [VideoCard] = []
    private(set) var page = 0
    private(set) var pages = 1
    private(set) var total = 0
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var error: String?

    private var seen = Set<Int>()

    init(channel: ChannelInfo, discovery: VideoDiscoveryRepository) {
        self.channel = channel
        self.discovery = discovery
    }

    var hasMore: Bool { page < pages }
    var isEmpty: Bool { items.isEmpty }

    func loadInitial() async {
        guard items.isEmpty, !isLoading else { return }
        await load(page: 1, replace: true)
    }

    func retry() async {
        if items.isEmpty {
            await load(page: 1, replace: true)
        } else if hasMore {
            await load(page: page + 1, replace: false)
        }
    }

    func loadMoreIfNeeded(currentID: Int) async {
        guard !isLoading, !isLoadingMore, hasMore else { return }
        guard let index = items.firstIndex(where: { $0.id == currentID }) else { return }
        guard index >= items.count - 3 else { return }
        await load(page: page + 1, replace: false)
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
            let response = try await discovery.category(
                cate: channel.cate,
                page: nextPage,
                size: pageSize
            )
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
