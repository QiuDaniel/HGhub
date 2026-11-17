import SwiftUI

enum AppTab: Hashable {
    case home
    case search
    case category
    case profile
}

struct RootTabView: View {
    let deps: AppDependencies

    @State private var tab: AppTab = .home
    @State private var homePath: [Route] = []
    @State private var searchPath: [Route] = []
    @State private var categoryPath: [Route] = []
    @State private var profilePath: [Route] = []

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $homePath) {
                HomeView(deps: deps)
                    .navigationDestination(for: Route.self) { destination($0) }
            }
            .tabItem { Label("首页", systemImage: "house.fill") }
            .tag(AppTab.home)

            NavigationStack(path: $searchPath) {
                SearchView()
                    .navigationDestination(for: Route.self) { destination($0) }
            }
            .tabItem { Label("搜索", systemImage: "magnifyingglass") }
            .tag(AppTab.search)

            NavigationStack(path: $categoryPath) {
                CategoryView()
                    .navigationDestination(for: Route.self) { destination($0) }
            }
            .tabItem { Label("分类", systemImage: "square.grid.2x2") }
            .tag(AppTab.category)

            NavigationStack(path: $profilePath) {
                ProfileView()
                    .navigationDestination(for: Route.self) { destination($0) }
            }
            .tabItem { Label("我的", systemImage: "person") }
            .tag(AppTab.profile)
        }
        .tint(Color.hgPrimary)
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .channel(let cate, let name):
            Text("频道 \(name)（\(cate)）")
                .navigationTitle(name)
        case .ranks:
            Text("榜单")
                .navigationTitle("榜单")
        case .settings:
            SettingsView()
        case .posts:
            PostsView()
        case .post(let id):
            Text("帖子 \(id)")
                .navigationTitle("帖子")
        }
    }
}
