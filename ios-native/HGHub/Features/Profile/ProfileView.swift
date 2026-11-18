import NukeUI
import SwiftUI

struct ProfileView: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @State private var model: LibraryViewModel
    @State private var showClearHistory = false
    @State private var showLogout = false

    init(deps: AppDependencies) {
        self.deps = deps
        _model = State(initialValue: LibraryViewModel(
            library: deps.library,
            social: deps.social
        ))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                profileCard
                stats
                settingsRow
                favoritesSection
                historySection
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(Color.hgCanvas)
        .navigationTitle("我的")
        .task {
            await model.load()
        }
        .onAppear {
            Task { await model.load() }
        }
        .refreshable {
            await model.refresh()
        }
        .onChange(of: deps.library.favorites) { _, _ in
            guard app.feed == nil else { return }
            Task { await model.load() }
        }
        .onChange(of: deps.library.history) { _, _ in
            guard app.feed == nil else { return }
            Task { await model.load() }
        }
        .confirmationDialog("清空观看历史？", isPresented: $showClearHistory, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                deps.library.clearHistory()
                app.showToast("观看历史已清空", icon: .ok)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只清空观看进度，收藏和登录状态会保留。")
        }
        .confirmationDialog("退出登录？", isPresented: $showLogout, titleVisibility: .visible) {
            Button("退出", role: .destructive) { logout() }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 资料卡

    @ViewBuilder
    private var profileCard: some View {
        if let session = app.session {
            HStack(spacing: 14) {
                HGAvatar(name: session.user?.nickname ?? "我", size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.user?.nickname ?? "已登录")
                        .font(.title3.weight(.bold))
                    if let username = session.user?.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundStyle(Color.hgTextSecondary)
                    } else {
                        Text("已登录")
                            .font(.caption)
                            .foregroundStyle(Color.hgTextSecondary)
                    }
                }
                Spacer()
                Button("退出") {
                    showLogout = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .accessibilityIdentifier("profileLogout")
            }
            .padding(14)
            .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 16))
        } else {
            Button {
                app.loginPresented = true
            } label: {
                HStack(spacing: 14) {
                    HGAvatar(name: "未登录", size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("未登录")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.hgText)
                        Text("登录后可点赞、收藏、关注和评论")
                            .font(.caption)
                            .foregroundStyle(Color.hgTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.hgTextSecondary)
                }
                .padding(14)
                .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profileLogin")
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("收藏", deps.library.favorites.count)
            Divider().frame(height: 28)
            stat("历史", deps.library.history.count)
            Divider().frame(height: 28)
            stat("搜索", deps.library.searchHistory.count)
        }
        .padding(.vertical, 12)
        .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.hgTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 收藏

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("我的收藏", count: model.favorites.count)

            if model.isLoading, model.favorites.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if model.favorites.isEmpty {
                emptyHint("还没有收藏，去首页逛逛")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 10) {
                        ForEach(Array(model.favorites.enumerated()), id: \.element.id) { index, card in
                            Button {
                                openFavorites(index: index)
                            } label: {
                                VideoCardCell(card: card)
                                    .frame(width: 132)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("favoriteCard_\(card.id)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 历史

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("观看历史", count: model.historyTotal)
                if !deps.library.history.isEmpty {
                    Button("清空") {
                        showClearHistory = true
                    }
                    .font(.caption)
                    .foregroundStyle(Color.hgTextSecondary)
                }
            }

            if model.isLoading, model.history.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if model.history.isEmpty {
                emptyHint("还没有观看记录")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(model.history.enumerated()), id: \.element.id) { index, item in
                        Button {
                            openHistory(index: index)
                        } label: {
                            HistoryRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("historyRow_\(item.card.id)")
                    }
                }

                if model.historyTotal > model.history.count {
                    Text("仅展示最近 \(model.history.count) 条，共 \(model.historyTotal) 条")
                        .font(.caption2)
                        .foregroundStyle(Color.hgTextSecondary)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(Color.hgTextSecondary)
            Spacer()
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color.hgTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }

    private var settingsRow: some View {
        NavigationLink(value: Route.settings) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .foregroundStyle(Color.hgPrimary)
                    .frame(width: 30)
                Text("设置")
                    .foregroundStyle(Color.hgText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.hgTextSecondary)
            }
            .padding(14)
            .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func openFavorites(index: Int) {
        app.presentFeed(
            cards: model.favorites,
            index: index,
            title: "我的收藏",
            source: "favorites",
            page: 1,
            pages: 1,
            library: deps.library
        )
    }

    private func openHistory(index: Int) {
        app.presentFeed(
            cards: model.history.map(\.card),
            index: index,
            title: "观看历史",
            source: "history",
            page: 1,
            pages: 1,
            library: deps.library
        )
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
}

private struct HistoryRow: View {
    let item: LibraryHistoryItem

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Color.hgSurface2
                LazyImage(url: URL(string: item.card.cover ?? "")) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.hgSurface2
                    }
                }
                .scaledToFill()
            }
            .frame(width: 54, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.card.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.hgText)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text("第 \(item.progress.ep) 集")
                    if item.progress.dur > 0 {
                        Text("· \(Int(min(item.progress.t / item.progress.dur, 1) * 100))%")
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.hgTextSecondary)

                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.hgPrimary)
                        .frame(width: proxy.size.width * progress, height: 3)
                        .background(Color.hgSurface2, in: Capsule())
                }
                .frame(height: 3)
            }

            Spacer(minLength: 0)
            Image(systemName: "play.fill")
                .font(.caption)
                .foregroundStyle(Color.hgTextSecondary)
        }
        .padding(10)
        .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.card.displayTitle)，第 \(item.progress.ep) 集，进度 \(Int(progress * 100))%")
    }

    private var progress: CGFloat {
        guard item.progress.dur > 0 else { return 0 }
        return CGFloat(min(max(item.progress.t / item.progress.dur, 0), 1))
    }
}
