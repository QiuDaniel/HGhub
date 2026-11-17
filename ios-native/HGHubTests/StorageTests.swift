import Foundation
import Testing
@testable import HGHub

@MainActor
struct LocalLibraryTests {
    private func makeLibrary() throws -> LocalLibrary {
        let name = "test_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let suite = try #require(UserDefaults(suiteName: name))
        return LocalLibrary(suite: suite, namespace: name)
    }

    @Test
    func togglesFavoritesLikesAndFollows() throws {
        let library = try makeLibrary()

        #expect(!library.isFavorite(1))
        #expect(library.toggleFavorite(1))
        #expect(library.isFavorite(1))
        #expect(!library.toggleFavorite(1))
        #expect(!library.isFavorite(1))

        #expect(library.toggleLike(2))
        #expect(library.isLiked(2))
        #expect(library.toggleFollow(3))
        #expect(library.isFollowing(3))
    }

    @Test
    func historyCapsAt80AndKeepsNewestFirst() throws {
        let library = try makeLibrary()
        for id in 0..<85 {
            library.recordHistory(id: id, ep: 1, time: 10, duration: 20)
        }

        #expect(library.history.count == 80)
        #expect(library.history.first?.id == 84)
        #expect(library.history.last?.id == 5)
    }

    @Test
    func changingEpisodeResetsTimeButSameEpisodeKeepsIt() throws {
        let library = try makeLibrary()

        library.recordHistory(id: 1, ep: 1, time: 30, duration: 60)
        library.recordHistory(id: 1, ep: 1, time: 42, duration: 60)
        #expect(library.historyProgress(for: 1)?.t == 42)

        library.recordHistory(id: 1, ep: 2, time: 42, duration: 60)
        #expect(library.historyProgress(for: 1)?.ep == 2)
        #expect(library.historyProgress(for: 1)?.t == 0)
    }

    @Test
    func persistsAcrossInstances() throws {
        let name = "test_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let suite = try #require(UserDefaults(suiteName: name))

        let first = LocalLibrary(suite: suite, namespace: name)
        first.toggleFavorite(1)
        first.recordHistory(id: 2, ep: 3, time: 40, duration: 100)

        let second = LocalLibrary(suite: suite, namespace: name)
        #expect(second.isFavorite(1))
        #expect(second.historyProgress(for: 2)?.ep == 3)
        #expect(second.historyProgress(for: 2)?.t == 40)
    }

    @Test
    func searchHistoryDeduplicatesAndCapsAt12() throws {
        let library = try makeLibrary()

        library.addSearch(" a ")
        library.addSearch("b")
        library.addSearch("a")
        #expect(library.searchHistory == ["a", "b"])

        for index in 0..<20 {
            library.addSearch("q\(index)")
        }
        #expect(library.searchHistory.count == 12)
        #expect(library.searchHistory.first == "q19")
    }
}

@MainActor
struct LineStoreTests {
    private func makeStore() throws -> (LineStore, UserDefaults, String) {
        let name = "line_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let suite = try #require(UserDefaults(suiteName: name))
        return (LineStore(suite: suite, namespace: name), suite, name)
    }

    @Test
    func selectsAndPersistsFixedLine() throws {
        let (store, suite, namespace) = try makeStore()
        #expect(store.current.url == LineStore.fixed[0].url)

        #expect(store.select(LineStore.fixed[1]))
        #expect(store.current.url == LineStore.fixed[1].url)

        let reloaded = LineStore(suite: suite, namespace: namespace)
        #expect(reloaded.current.url == LineStore.fixed[1].url)
    }

    @Test
    func rejectsInvalidSchemes() throws {
        let (store, _, _) = try makeStore()
        #expect(!store.select(url: "ftp://example.com"))
        #expect(!store.select(url: "not a url"))
        #expect(store.current.url == LineStore.fixed[0].url)
    }

    @Test
    func normalizesTrailingSlash() {
        #expect(LineStore.normalized("https://huangguoai.com/") == "https://huangguoai.com")
        #expect(LineStore.normalized("https://huangguoai.com") == "https://huangguoai.com")
    }
}
