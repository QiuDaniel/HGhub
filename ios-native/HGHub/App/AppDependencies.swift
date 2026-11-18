import Foundation

/// 组合根：只在这里组装具体实现，Feature 只依赖协议。
@MainActor
final class AppDependencies {
    let api: APIClient
    let videos: VideoRepository
    let account: AccountRepository
    let social: VideoSocialRepository
    let session: SessionStore
    let library: LocalLibrary
    let lines: LineStore

    init() {
        AppImagePipeline.install()

        let api = APIClient()
        self.api = api
        self.videos = LiveVideoRepository(api: api)
        self.account = LiveAccountRepository(api: api)
        self.social = LiveVideoSocialRepository(api: api)
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

    /// 401：清 Keychain、清 APIClient token、回到未登录态并弹一次登录。
    func handleUnauthorized(app: AppState) async {
        await api.setToken(nil)
        session.clear()
        app.signOut()
        app.loginPresented = true
    }
}
