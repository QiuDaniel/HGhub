import NukeUI
import SwiftUI

struct DetailSheet: View {
    let interactions: FeedInteractionModel
    let deps: AppDependencies
    let onSelectEpisode: (Int) -> Void
    let onRequireLogin: () -> Void

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var expanded = false

    private var coverURL: URL? {
        URL(string: interactions.detail?.cover ?? interactions.card?.cover ?? "")
    }

    private var score: Double? {
        interactions.detail?.score ?? interactions.card?.score
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    cover
                    header
                    counts
                    actions
                    description
                    episodes
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.hgCanvas)
            .navigationTitle("详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await interactions.loadDetail()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var cover: some View {
        ZStack(alignment: .bottomLeading) {
            Color.hgSurface2
            LazyImage(url: coverURL) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else if state.error != nil {
                    Color.hgSurface2
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(Color.hgTextSecondary)
                        }
                } else {
                    Color.hgSurface2.overlay { ProgressView() }
                }
            }
            .scaledToFill()

            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(interactions.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text("@\(interactions.authorName)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.86))
                    if let score {
                        Text(String(format: "%.1f", score))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.hgPrimary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.45), in: Capsule())
                    }
                }
            }
            .padding(12)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !interactions.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(interactions.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .foregroundStyle(Color.hgTextSecondary)
                                .background(Color.hgSurface, in: Capsule())
                        }
                    }
                }
            }

            HStack(spacing: 14) {
                Label("\(interactions.episodeTotal) 集", systemImage: "rectangle.stack")
                if let finished = interactions.detail?.isFinished {
                    Label(finished ? "已完结" : "连载中", systemImage: finished ? "checkmark.circle" : "clock")
                }
            }
            .font(.caption)
            .foregroundStyle(Color.hgTextSecondary)
        }
    }

    private var counts: some View {
        HStack(spacing: 0) {
            countItem("点赞", interactions.likeCount, icon: "heart.fill")
            countItem("收藏", interactions.collectCount, icon: "star.fill")
            countItem("评论", interactions.commentCount, icon: "text.bubble.fill")
        }
        .padding(.vertical, 12)
        .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func countItem(_ title: String, _ value: Int, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(compact(value))
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Color.hgText)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.hgTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            actionButton(
                title: interactions.liked ? "已点赞" : "点赞",
                icon: interactions.liked ? "heart.fill" : "heart",
                active: interactions.liked,
                identifier: "detailLike"
            ) {
                guard requireLogin() else { return }
                Task {
                    let outcome = await interactions.toggleLike()
                    await handle(outcome, success: interactions.liked ? "已点赞" : "已取消点赞")
                }
            }

            actionButton(
                title: interactions.collected ? "已收藏" : "收藏",
                icon: interactions.collected ? "star.fill" : "star",
                active: interactions.collected,
                identifier: "detailCollect"
            ) {
                guard requireLogin() else { return }
                Task {
                    let outcome = await interactions.toggleCollect()
                    await handle(outcome, success: interactions.collected ? "已收藏" : "已取消收藏")
                }
            }

            if let authorID = interactions.authorID, authorID > 0 {
                actionButton(
                    title: interactions.following ? "已关注" : "关注",
                    icon: interactions.following ? "person.fill.checkmark" : "person.badge.plus",
                    active: interactions.following,
                    identifier: "detailFollow"
                ) {
                    guard requireLogin() else { return }
                    Task {
                        let next = !interactions.following
                        let outcome = await interactions.toggleFollow()
                        await handle(outcome, success: next ? "已关注" : "已取消关注")
                    }
                }
            }

            ShareLink(
                item: shareURL,
                subject: Text(interactions.title),
                message: Text(interactions.title)
            ) {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text("分享")
                        .font(.caption2.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .foregroundStyle(Color.hgTextSecondary)
                .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("分享")
            .accessibilityIdentifier("detailShare")
        }
    }

    private func actionButton(title: String, icon: String, active: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(active ? Color.hgPrimary : Color.hgTextSecondary)
            .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("简介")
                    .font(.headline)
                Spacer()
                if interactions.description.count > 80 {
                    Button(expanded ? "收起" : "展开") {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.hgPrimary)
                }
            }

            Text(interactions.description.isEmpty ? "暂无简介" : interactions.description)
                .font(.subheadline)
                .foregroundStyle(Color.hgTextSecondary)
                .lineLimit(expanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var episodes: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("选集")
                    .font(.headline)
                Text("共 \(interactions.episodeTotal) 集")
                    .font(.caption)
                    .foregroundStyle(Color.hgTextSecondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 8)], spacing: 8) {
                ForEach(interactions.detail?.episodeList ?? fallbackEpisodes, id: \.epNum) { episode in
                    Button {
                        onSelectEpisode(episode.epNum)
                        dismiss()
                    } label: {
                        Text("\(episode.epNum)")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .foregroundStyle(episode.epNum == interactions.ep ? Color.hgOnPrimary : Color.hgText)
                            .background(
                                episode.epNum == interactions.ep ? Color.hgPrimary : Color.hgSurface,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("detailEpisode_\(episode.epNum)")
                }
            }
        }
    }

    private var fallbackEpisodes: [VideoDetail.Episode] {
        (1...interactions.episodeTotal).map { VideoDetail.Episode(epNum: $0) }
    }

    private var shareURL: URL {
        URL(string: "\(deps.lines.current.url)/video/\(interactions.videoID)/")
            ?? deps.lines.currentURL
    }

    private func requireLogin() -> Bool {
        guard app.session == nil else { return true }
        onRequireLogin()
        return false
    }

    private func handle(_ outcome: InteractionOutcome, success: String) async {
        switch outcome {
        case .ok:
            app.showToast(success, icon: .ok)
        case .needsLogin:
            onRequireLogin()
        case .unauthorized:
            await deps.handleUnauthorized(app: app)
            onRequireLogin()
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
