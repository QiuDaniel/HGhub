import NukeUI
import SwiftUI

struct PostsView: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @State private var model: PostsViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 10, alignment: .top),
        GridItem(.flexible(), spacing: 10, alignment: .top),
    ]

    init(deps: AppDependencies) {
        self.deps = deps
        _model = State(initialValue: PostsViewModel(repository: deps.posts))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                header

                if model.isEmpty, model.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else if model.isEmpty, let error = model.error {
                    VStack(spacing: 12) {
                        HGEmptyState(icon: "text.bubble", title: "加载失败", message: error)
                        Button("重试") {
                            Task { await model.retry() }
                        }
                        .buttonStyle(HGPrimaryButtonStyle())
                    }
                } else if model.isEmpty {
                    HGEmptyState(icon: "text.bubble", title: "暂无吃瓜内容", message: "稍后再来看看")
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(model.items) { post in
                            NavigationLink {
                                PostDetailView(id: post.id, deps: deps)
                            } label: {
                                PostCardCell(post: post)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("postCard_\(post.id)")
                            .task {
                                await model.loadMoreIfNeeded(currentID: post.id)
                            }
                        }
                    }

                    if model.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    } else if !model.hasMore {
                        Text("— 已经到底啦 —")
                            .font(.caption2)
                            .foregroundStyle(Color.hgTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(Color.hgCanvas)
        .navigationTitle("吃瓜")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.loadInitial()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Color.hgPrimary)
            Text("黄果吃瓜")
                .font(.headline)
            Text("圈内爆料 · 每日更新")
                .font(.caption)
                .foregroundStyle(Color.hgTextSecondary)
            Spacer()
            if model.total > 0 {
                Text("\(model.total) 条")
                    .font(.caption2)
                    .foregroundStyle(Color.hgTextSecondary)
            }
        }
    }
}

private struct PostCardCell: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                Color.hgSurface2
                LazyImage(url: URL(string: post.cover ?? "")) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.hgSurface2
                    }
                }
                .scaledToFill()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.displayTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text(compact(post.hot ?? 0))
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                }
                .padding(8)
            }
            .aspectRatio(4 / 5, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(post.displayTitle)，热度 \(post.hot ?? 0)")
    }

    private func compact(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.1fw", Double(value) / 10_000)
        }
        return "\(value)"
    }
}

struct PostDetailView: View {
    let id: Int
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @State private var model: PostDetailViewModel
    @State private var attributed: NSAttributedString?
    @State private var showComments = false

    init(id: Int, deps: AppDependencies) {
        self.id = id
        self.deps = deps
        _model = State(initialValue: PostDetailViewModel(postID: id, repository: deps.posts))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let error = model.error {
                    VStack(spacing: 12) {
                        HGEmptyState(icon: "text.bubble", title: "加载失败", message: error)
                        Button("重试") {
                            Task { await load() }
                        }
                        .buttonStyle(HGPrimaryButtonStyle())
                    }
                } else if let post = model.post {
                    cover(post)
                    meta(post)
                    interactionBar(post)
                    if let attributed {
                        HTMLContentView(attributed: attributed)
                            .padding(.top, 2)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 90)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.hgCanvas)
        .navigationTitle("吃瓜详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .sheet(isPresented: $showComments) {
            PostCommentsSheet(
                postID: id,
                deps: deps,
                onRequireLogin: {
                    showComments = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        app.loginPresented = true
                    }
                },
                onSent: { model.noteCommentSent() }
            )
        }
    }

    private func cover(_ post: Post) -> some View {
        ZStack {
            Color.hgSurface2
            LazyImage(url: URL(string: post.cover ?? "")) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Color.hgSurface2
                }
            }
            .scaledToFill()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func meta(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.displayTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.hgText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(post.displayAuthor)
                    .font(.caption.weight(.semibold))
                if let time = post.displayTime.nilIfEmpty {
                    Text(time)
                        .font(.caption2)
                        .foregroundStyle(Color.hgTextSecondary)
                }
                if let hot = post.hot {
                    Label(compact(hot), systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.hgPrimary)
                }
            }

            if let tags = post.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundStyle(Color.hgTextSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.hgSurface, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private func interactionBar(_ post: Post) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleLike()
            } label: {
                Label("\(compact(model.likeCount))", systemImage: model.liked ? "heart.fill" : "heart")
                    .foregroundStyle(model.liked ? Color.hgPrimary : Color.hgTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.hgSurface, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("postLike")

            Button {
                toggleCollect()
            } label: {
                Label("\(compact(model.collectCount))", systemImage: model.collected ? "star.fill" : "star")
                    .foregroundStyle(model.collected ? Color.hgPrimary : Color.hgTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.hgSurface, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("postCollect")

            Button {
                showComments = true
            } label: {
                Label("\(compact(model.commentCount))", systemImage: "text.bubble")
                    .foregroundStyle(Color.hgTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.hgSurface, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("postComments")

            ShareLink(
                item: URL(string: "\(deps.lines.current.url)/post/\(post.id)") ?? deps.lines.currentURL,
                subject: Text(post.displayTitle),
                message: Text(post.displayTitle)
            ) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color.hgTextSecondary)
                    .frame(width: 40, height: 40)
                    .background(Color.hgSurface, in: Circle())
            }
            .accessibilityLabel("分享")
        }
    }

    private func load() async {
        await model.load()
        if let content = model.post?.content {
            attributed = PostHTMLRenderer.render(content, baseURL: deps.lines.currentURL)
        }
    }

    private func toggleLike() {
        guard app.requireLogin() else { return }
        Task {
            let outcome = await model.toggleLike()
            await handle(outcome, like: true)
        }
    }

    private func toggleCollect() {
        guard app.requireLogin() else { return }
        Task {
            let outcome = await model.toggleCollect()
            await handle(outcome, like: false)
        }
    }

    private func handle(_ outcome: InteractionOutcome, like: Bool) async {
        switch outcome {
        case .ok:
            if like {
                app.showToast(model.liked ? "已点赞" : "已取消点赞", icon: .heart)
            } else {
                app.showToast(model.collected ? "已收藏" : "已取消收藏", icon: .star)
            }
        case .needsLogin:
            app.loginPresented = true
        case .unauthorized:
            await deps.handleUnauthorized(app: app)
            app.loginPresented = true
        case .failed(let message):
            app.showToast(message)
        }
    }

    private func compact(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.1fw", Double(value) / 10_000)
        }
        return "\(value)"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
