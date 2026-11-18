import Foundation
import Observation

@MainActor
@Observable
final class RankViewModel {
    private let discovery: VideoDiscoveryRepository

    private(set) var kind: RankKind = .hot
    private(set) var items: [RankItem] = []
    private(set) var isLoading = false
    var error: String?
    private var generation = 0

    init(discovery: VideoDiscoveryRepository) {
        self.discovery = discovery
    }

    func load(kind: RankKind? = nil) async {
        if let kind {
            self.kind = kind
        }
        generation += 1
        let run = generation
        isLoading = true
        error = nil
        defer {
            if run == generation { isLoading = false }
        }

        do {
            let page = try await discovery.ranks(kind: self.kind)
            guard run == generation, !Task.isCancelled else { return }
            items = Array(page.items.prefix(20))
        } catch is CancellationError {
            return
        } catch {
            guard run == generation else { return }
            items = []
            self.error = error.localizedDescription
        }
    }

    func select(_ kind: RankKind) async {
        guard kind != self.kind || items.isEmpty else { return }
        await load(kind: kind)
    }
}
