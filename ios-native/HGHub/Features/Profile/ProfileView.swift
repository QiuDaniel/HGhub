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
                    Button("登录") {
                        app.loginPresented = true
                    }
                    .buttonStyle(HGPrimaryButtonStyle())
                    .accessibilityIdentifier("profileLogin")
                }
            } else {
                Section {
                    Button("退出登录", role: .destructive) {
                        logout()
                    }
                    .accessibilityIdentifier("profileLogout")
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

    private func logout() {
        Task {
            try? await deps.account.logout()
            deps.session.clear()
            await deps.api.setToken(nil)
            app.signOut()
            app.showToast("已退出登录", icon: .ok)
        }
    }

    private var displayName: String {
        app.session?.user?.nickname ?? "未登录"
    }

    private var subtitle: String {
        guard let session = app.session else {
            return "登录后可同步点赞、收藏与评论"
        }
        let username = session.user?.username ?? ""
        return username.isEmpty ? "已登录" : "@\(username)"
    }
}
