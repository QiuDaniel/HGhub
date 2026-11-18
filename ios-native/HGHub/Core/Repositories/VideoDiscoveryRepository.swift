import Foundation

protocol VideoDiscoveryRepository: Sendable {
    func category(cate: String, page: Int, size: Int) async throws -> Paged<VideoCard>
    func search(query: String, page: Int, size: Int) async throws -> Paged<VideoCard>
    func ranks(kind: RankKind) async throws -> RankPage
}

struct LiveVideoDiscoveryRepository: VideoDiscoveryRepository {
    let api: APIClient

    func category(cate: String, page: Int, size: Int) async throws -> Paged<VideoCard> {
        try await api.get(
            "/api/videos?cate_id=\(cate)&page=\(page)&size=\(size)",
            as: Paged<VideoCard>.self
        )
    }

    func search(query: String, page: Int, size: Int) async throws -> Paged<VideoCard> {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        return try await api.get(
            "/api/search?q=\(encoded)&page=\(page)&size=\(size)",
            as: Paged<VideoCard>.self
        )
    }

    func ranks(kind: RankKind) async throws -> RankPage {
        try await api.get("/api/ranks/\(kind.rawValue)", as: RankPage.self)
    }
}
