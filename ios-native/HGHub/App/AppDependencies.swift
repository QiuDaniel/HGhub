import Foundation

/// 组合根：只在这里组装具体实现，Feature 只依赖协议。
@MainActor
final class AppDependencies {
    let api: APIClient
    let videos: VideoRepository
    let session: SessionStore

    init() {
        AppImagePipeline.install()
        let api = APIClient()
        self.api = api
        self.videos = LiveVideoRepository(api: api)
        self.session = SessionStore()
    }
}
