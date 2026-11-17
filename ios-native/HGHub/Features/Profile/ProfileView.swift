import SwiftUI

struct ProfileView: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    HGAvatar(name: displayName, size: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.title3.weight(.bold))
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.hgTextSecondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if app.session == nil {
                Section {
                    Button("登录 / 注册") {
                        app.loginPresented = true
                    }
                    .buttonStyle(HGPrimaryButtonStyle())
                }
            }

            Section("本地数据") {
                LabeledContent("收藏", value: "\(deps.library.favorites.count)")
                LabeledContent("观看历史", value: "\(deps.library.history.count)")
                LabeledContent("搜索历史", value: "\(deps.library.searchHistory.count)")
            }

            Section {
                NavigationLink(value: Route.settings) {
                    Label("设置", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("我的")
    }

    private var displayName: String {
        app.session?.user?.nickname ?? "未登录"
    }

    private var subtitle: String {
        guard let session = app.session else {
            return "浏览与本地收藏可用；登录在 M3 接入"
        }
        let username = session.user?.username ?? ""
        return username.isEmpty ? "已登录" : "@\(username)"
    }
}
