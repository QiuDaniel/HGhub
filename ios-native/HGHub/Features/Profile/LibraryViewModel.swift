import Foundation
import Observation

struct LibraryHistoryItem: Identifiable, Sendable {
    let card: VideoCard
    let progress: WatchProgress

    var id: Int { card.id }
}

@MainActor
@Observable
final class LibraryViewModel {
    private let library: LocalLibrary
    private let social: VideoSocialRepository
    private let pageLimit = 30

    private(set) var favorites: [VideoCard] = []
    private(set) var history: [LibraryHistoryItem] = []
    private(set) var isLoading = false
    private(set) var loadedFavoriteIDs: [Int] = []
    private(set) var loadedHistoryIDs: [Int] = []
    var error: String?

    init(library: LocalLibrary, social: VideoSocialRepository) {
        self.library = library
        self.social = social
    }

    var historyTotal: Int { library.history.count }

    func load(force: Bool = false) async {
        guard !isLoading else { return }
        let favoriteIDs = library.favorites
        let historyEntries = Array(library.history.prefix(pageLimit))
        let historyIDs = historyEntries.map(\.id)

        if !force,
           favoriteIDs == loadedFavoriteIDs,
           historyIDs == loadedHistoryIDs,
           !favorites.isEmpty || !history.isEmpty {
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let ids = Array(Set(favoriteIDs + historyIDs))
        let cards = await fetch(ids: ids)

        favorites = favoriteIDs.map { cards[$0] ?? fallbackCard($0) }
        history = historyEntries.map { progress in
            LibraryHistoryItem(
                card: cards[progress.id] ?? fallbackCard(progress.id),
                progress: progress
            )
        }
        loadedFavoriteIDs = favoriteIDs
        loadedHistoryIDs = historyIDs
    }

    func refresh() async {
        await load(force: true)
    }

    private func fetch(ids: [Int]) async -> [Int: VideoCard] {
        guard !ids.isEmpty else { return [:] }
        let social = self.social
        var result: [Int: VideoCard] = [:]

        for start in stride(from: 0, to: ids.count, by: 6) {
            let chunk = Array(ids[start..<min(start + 6, ids.count)])
            await withTaskGroup(of: (Int, VideoCard?).self) { group in
                for id in chunk {
                    group.addTask {
                        do {
                            return (id, try await social.detail(id: id).card)
                        } catch {
                            return (id, nil)
                        }
                    }
                }
                for await (id, card) in group {
                    if let card { result[id] = card }
                }
            }
        }
        return result
    }

    private func fallbackCard(_ id: Int) -> VideoCard {
        VideoCard(id: id, title: "视频 \(id)")
    }
}
