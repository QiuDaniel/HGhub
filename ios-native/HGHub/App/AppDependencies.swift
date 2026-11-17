import Foundation

/// 组合根：只在这里组装具体实现，Feature 只依赖协议。
@MainActor
final class AppDependencies {
    let api: APIClient
    let videos: VideoRepository
    let session: SessionStore
    let library: LocalLibrary
    let lines: LineStore

    init() {
        AppImagePipeline.install()

        let api = APIClient()
        self.api = api
        self.videos = LiveVideoRepository(api: api)
        self.session = SessionStore()
        self.library = LocalLibrary()
        self.lines = LineStore()
    }

    /// 启动时把持久化的线路 / 会话注入 APIClient，并恢复 AppState 的登录态。
    func bootstrap(app: AppState) async {
        await api.setBase(lines.currentURL)

        if let session = session.session {
            app.apply(session: session)
            await api.setToken(session.token)
        }
    }
}
