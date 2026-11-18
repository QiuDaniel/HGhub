import Defaults
import Foundation
import Observation

/// 本地库：收藏 / 喜欢 / 关注 / 观看历史 / 搜索历史。
/// 用 Defaults 落盘；数组同时作为 `@Observable` 的存储属性，UI 才能随写入刷新。
@MainActor
@Observable
final class LocalLibrary {
    @ObservationIgnored private let favoritesKey: Defaults.Key<[Int]>
    @ObservationIgnored private let likesKey: Defaults.Key<[Int]>
    @ObservationIgnored private let followsKey: Defaults.Key<[Int]>
    @ObservationIgnored private let historyKey: Defaults.Key<[WatchProgress]>
    @ObservationIgnored private let searchKey: Defaults.Key<[String]>

    private(set) var favorites: [Int]
    private(set) var likes: [Int]
    private(set) var follows: [Int]
    private(set) var history: [WatchProgress]
    private(set) var searchHistory: [String]

    init(suite: UserDefaults = .standard, namespace: String = "hghub") {
        let favoritesKey = Defaults.Key<[Int]>("\(namespace)_favorites", default: [], suite: suite)
        let likesKey = Defaults.Key<[Int]>("\(namespace)_likes", default: [], suite: suite)
        let followsKey = Defaults.Key<[Int]>("\(namespace)_follows", default: [], suite: suite)
        let historyKey = Defaults.Key<[WatchProgress]>("\(namespace)_history", default: [], suite: suite)
        let searchKey = Defaults.Key<[String]>("\(namespace)_search", default: [], suite: suite)

        self.favoritesKey = favoritesKey
        self.likesKey = likesKey
        self.followsKey = followsKey
        self.historyKey = historyKey
        self.searchKey = searchKey

        self.favorites = Defaults[favoritesKey]
        self.likes = Defaults[likesKey]
        self.follows = Defaults[followsKey]
        self.history = Defaults[historyKey]
        self.searchHistory = Defaults[searchKey]
    }

    // MARK: - 收藏 / 喜欢 / 关注

    func isFavorite(_ id: Int) -> Bool { favorites.contains(id) }
    func isLiked(_ id: Int) -> Bool { likes.contains(id) }
    func isFollowing(_ uid: Int) -> Bool { follows.contains(uid) }

    @discardableResult
    func toggleFavorite(_ id: Int) -> Bool {
        if let index = favorites.firstIndex(of: id) {
            favorites.remove(at: index)
        } else {
            favorites.insert(id, at: 0)
        }
        Defaults[favoritesKey] = favorites
        return favorites.contains(id)
    }

    func setLiked(_ id: Int, _ liked: Bool) {
        if liked {
            guard !likes.contains(id) else { return }
            likes.insert(id, at: 0)
        } else {
            likes.removeAll { $0 == id }
        }
        Defaults[likesKey] = likes
    }

    func setFavorite(_ id: Int, _ favorite: Bool) {
        if favorite {
            guard !favorites.contains(id) else { return }
            favorites.insert(id, at: 0)
        } else {
            favorites.removeAll { $0 == id }
        }
        Defaults[favoritesKey] = favorites
    }

    func setFollowing(_ uid: Int, _ following: Bool) {
        if following {
            guard !follows.contains(uid) else { return }
            follows.insert(uid, at: 0)
        } else {
            follows.removeAll { $0 == uid }
        }
        Defaults[followsKey] = follows
    }

    @discardableResult
    func toggleLike(_ id: Int) -> Bool {
        if let index = likes.firstIndex(of: id) {
            likes.remove(at: index)
        } else {
            likes.insert(id, at: 0)
        }
        Defaults[likesKey] = likes
        return likes.contains(id)
    }

    @discardableResult
    func toggleFollow(_ uid: Int) -> Bool {
        if let index = follows.firstIndex(of: uid) {
            follows.remove(at: index)
        } else {
            follows.insert(uid, at: 0)
        }
        Defaults[followsKey] = follows
        return follows.contains(uid)
    }

    // MARK: - 观看历史

    func historyProgress(for id: Int) -> WatchProgress? {
        history.first { $0.id == id }
    }

    /// 记录进度；`ep` 变化时秒数归零，同集保留上次秒数。最多 80 条。
    func recordHistory(id: Int, ep: Int? = nil, time: Double? = nil, duration: Double? = nil) {
        guard id > 0 else { return }
        let previous = history.first { $0.id == id }
        let nextEpisode = ep ?? previous?.ep ?? 1
        let episodeChanged = previous.map { $0.ep != nextEpisode } ?? false

        let entry = WatchProgress(
            id: id,
            ep: nextEpisode,
            t: episodeChanged ? 0 : (time ?? previous?.t ?? 0),
            dur: duration ?? previous?.dur ?? 0,
            at: Date()
        )

        history.removeAll { $0.id == id }
        history.insert(entry, at: 0)
        if history.count > 80 {
            history = Array(history.prefix(80))
        }
        Defaults[historyKey] = history
    }

    func clearHistory() {
        history = []
        Defaults[historyKey] = history
    }

    // MARK: - 搜索历史

    func addSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchHistory.removeAll { $0 == trimmed }
        searchHistory.insert(trimmed, at: 0)
        if searchHistory.count > 12 {
            searchHistory = Array(searchHistory.prefix(12))
        }
        Defaults[searchKey] = searchHistory
    }

    func clearSearchHistory() {
        searchHistory = []
        Defaults[searchKey] = searchHistory
    }
}
