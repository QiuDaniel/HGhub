import SwiftUI

struct CategoryView: View {
    let deps: AppDependencies
    let onOpenChannel: (ChannelInfo) -> Void
    let onOpenRanks: () -> Void
    let onOpenPosts: () -> Void

    @Environment(AppState.self) private var app
    @State private var model: CategoryViewModel

    init(
        deps: AppDependencies,
        onOpenChannel: @escaping (ChannelInfo) -> Void,
        onOpenRanks: @escaping () -> Void,
        onOpenPosts: @escaping () -> Void
    ) {
        self.deps = deps
        self.onOpenChannel = onOpenChannel
        self.onOpenRanks = onOpenRanks
        self.onOpenPosts = onOpenPosts
        _model = State(initialValue: CategoryViewModel(discovery: deps.discovery))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header
                rankEntry
                postsEntry

                if model.isLoading, model.rows.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 70)
                } else if model.rows.isEmpty {
                    HGEmptyState(
                        icon: "square.grid.2x2",
                        title: "暂无分类内容",
                        message: "上游频道暂时为空，稍后再来看看"
                    )
                } else {
                    ForEach(model.rows) { row in
                        channelSection(row)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(Color.hgCanvas)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if model.rows.isEmpty {
                await model.load()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("分类")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.hgText)
            Text(model.isLoading ? "正在加载频道" : "\(model.rows.count) 个频道 · 每周持续上新")
                .font(.caption)
                .foregroundStyle(Color.hgTextSecondary)
        }
    }

    private var rankEntry: some View {
        Button(action: onOpenRanks) {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.hgPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.hgPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 2) {
                    Text("排行榜")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.hgText)
                    Text("热播榜 · 推荐榜 · 潜力榜")
                        .font(.caption2)
                        .foregroundStyle(Color.hgTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.hgTextSecondary)
            }
            .padding(12)
            .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("categoryRanks")
    }

    private var postsEntry: some View {
        Button(action: onOpenPosts) {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.hgPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.hgPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 2) {
                    Text("黄果吃瓜")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.hgText)
                    Text("圈内爆料 · 每日更新")
                        .font(.caption2)
                        .foregroundStyle(Color.hgTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.hgTextSecondary)
            }
            .padding(12)
            .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("categoryPosts")
    }

    private func channelSection(_ row: CategoryRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                onOpenChannel(row.channel)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.hgPrimary)
                        .frame(width: 34, height: 34)
                        .background(Color.hgPrimary.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.channel.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.hgText)
                        Text(row.channel.desc)
                            .font(.caption2)
                            .foregroundStyle(Color.hgTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("全部")
                        .font(.caption2)
                        .foregroundStyle(Color.hgTextSecondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.hgTextSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityIdentifier("channelHeader_\(row.channel.cate)")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(Array(row.items.prefix(8).enumerated()), id: \.element.id) { index, card in
                        Button {
                            open(row: row, index: index)
                        } label: {
                            VideoCardCell(card: card)
                                .frame(width: 132)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("channelCard_\(row.channel.cate)_\(card.id)")
                    }
                }
                .padding(.horizontal, 0)
            }
        }
    }

    private func open(row: CategoryRow, index: Int) {
        app.presentFeed(
            cards: row.items,
            index: index,
            title: row.channel.name,
            source: "channel",
            page: 1,
            pages: row.pages,
            cate: row.channel.cate,
            library: deps.library
        )
    }
}

struct ChannelView: View {
    let channel: ChannelInfo
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @State private var model: ChannelViewModel

    init(cate: String, name: String, deps: AppDependencies) {
        let channel = ChannelInfo.all.first { $0.cate == cate }
            ?? ChannelInfo(cate: cate, name: name, desc: "频道 \(cate)")
        self.channel = channel
        self.deps = deps
        _model = State(initialValue: ChannelViewModel(channel: channel, discovery: deps.discovery))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(model.total > 0 ? "\(model.total) 部" : "全部内容")
                        .font(.caption)
                        .foregroundStyle(Color.hgTextSecondary)
                    Spacer()
                }

                if model.isEmpty, model.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 80)
                } else if model.isEmpty, let error = model.error {
                    VStack(spacing: 12) {
                        HGEmptyState(icon: "square.grid.2x2", title: "加载失败", message: error)
                        Button("重试") {
                            Task { await model.retry() }
                        }
                        .buttonStyle(HGPrimaryButtonStyle())
                    }
                } else if model.isEmpty {
                    HGEmptyState(icon: "square.grid.2x2", title: "暂无内容", message: "这个频道还没有短剧")
                } else {
                    VideoPosterGrid(
                        items: model.items,
                        onOpen: { open(index: $0) },
                        onNearEnd: { id in
                            Task { await model.loadMoreIfNeeded(currentID: id) }
                        }
                    )

                    if model.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else if !model.hasMore {
                        Text("— 已经到底啦 —")
                            .font(.caption2)
                            .foregroundStyle(Color.hgTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else if let error = model.error {
                        Button("加载失败：\(error) · 重试") {
                            Task { await model.retry() }
                        }
                        .font(.caption)
                        .foregroundStyle(Color.hgPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(Color.hgCanvas)
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.loadInitial()
        }
    }

    private func open(index: Int) {
        app.presentFeed(
            cards: model.items,
            index: index,
            title: channel.name,
            source: "channel",
            page: model.page,
            pages: model.pages,
            cate: channel.cate,
            library: deps.library
        )
    }
}
