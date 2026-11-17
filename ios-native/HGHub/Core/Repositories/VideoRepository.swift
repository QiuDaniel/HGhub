import Foundation

protocol VideoRepository: Sendable {
    func feed(page: Int, size: Int) async throws -> Paged<VideoCard>
    func playback(id: Int, ep: Int) async throws -> PlayInfo
}

struct LiveVideoRepository: VideoRepository {
    let api: APIClient

    func feed(page: Int, size: Int) async throws -> Paged<VideoCard> {
        try await api.get("/api/videos?page=\(page)&size=\(size)", as: Paged<VideoCard>.self)
    }

    func playback(id: Int, ep: Int) async throws -> PlayInfo {
        try await api.playback(id: id, ep: ep)
    }
}
