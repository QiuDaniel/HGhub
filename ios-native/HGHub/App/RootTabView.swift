import SwiftUI

enum AppTab: Hashable {
    case home
    case search
    case category
    case profile
}

struct RootTabView: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @State private var tab: AppTab = .home
    @State private var homePath: [Route] = []
    @State private var searchPath: [Route] = []
    @State private var categoryPath: [Route] = []
    @State private var profilePath: [Route] = []

    var body: some View {
        @Bindable var app = app

        TabView(selection: $tab) {
            NavigationStack(path: $homePath) {
                HomeView(deps: deps)
                    .navigationDestination(for: Route.self) { destination($0) }
            }
            .tabItem { Label("首页", systemImage: "house.fill") }
            .tag(AppTab.home)

            NavigationStack(path: $searchPath) {
                SearchView(deps: deps)
                    .navigationDestination(for: Route.self) { destination($0) }
            }
            .tabItem { Label("搜索", systemImage: "magnifyingglass") }
            .tag(AppTab.search)

            NavigationStack(path: $categoryPath) {
                CategoryView(
                    deps: deps,
                    onOpenChannel: { channel in
                        categoryPath = categoryPath + [.channel(cate: channel.cate, name: channel.name)]
                    },
                    onOpenRanks: {
                        categoryPath = categoryPath + [.ranks]
                    }
                )
                .navigationDestination(for: Route.self) { destination($0) }
            }
            .tabItem { Label("分类", systemImage: "square.grid.2x2") }
            .tag(AppTab.category)

            NavigationStack(path: $profilePath) {
                ProfileView(deps: deps)
                    .navigationDestination(for: Route.self) { destination($0) }
            }
            .tabItem { Label("我的", systemImage: "person") }
            .tag(AppTab.profile)
        }
        .tint(Color.hgPrimary)
        .task {
            await deps.bootstrap(app: app)
        }
        .sheet(isPresented: loginBinding) {
            LoginSheet(deps: deps)
        }
        .fullScreenCover(item: $app.feed) { context in
            FeedScreen(context: context, deps: deps)
                .environment(app)
        }
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { app.loginPresented && app.feed == nil },
            set: { app.loginPresented = $0 }
        )
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .channel(let cate, let name):
            ChannelView(cate: cate, name: name, deps: deps)
        case .ranks:
            RankView(deps: deps)
        case .settings:
            SettingsView(deps: deps)
        case .posts:
            PostsView()
        case .post(let id):
            PostDetailView(id: id)
        }
    }
}
