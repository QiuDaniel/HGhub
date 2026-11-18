import SwiftUI

struct SearchView: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @State private var model: SearchViewModel
    @State private var query = ""
    @FocusState private var focused: Bool

    private let hotTags = ["都市", "逆袭", "古风", "系统", "后宫", "校园", "仙侠", "职场", "大男主", "御姐", "脑洞", "奇幻"]

    init(deps: AppDependencies) {
        self.deps = deps
        _model = State(initialValue: SearchViewModel(
            discovery: deps.discovery,
            library: deps.library
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if model.isSearching {
                        results
                    } else {
                        discovery
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.hgCanvas)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.hgTextSecondary)
                TextField("搜索短剧、作者、题材…", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .onSubmit { search(query) }
                    .accessibilityIdentifier("searchField")
                if !query.isEmpty {
                    Button {
                        query = ""
                        model.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.hgTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空搜索")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 13))

            NavigationLink(value: Route.ranks) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.hgOnPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.hgPrimary, in: RoundedRectangle(cornerRadius: 13))
            }
            .accessibilityLabel("排行榜")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - 未搜索：历史 + 热门题材

    private var discovery: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !deps.library.searchHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("搜索历史")
                            .font(.headline)
                        Spacer()
                        Button("清空") {
                            deps.library.clearSearchHistory()
                        }
                        .font(.caption)
                        .foregroundStyle(Color.hgTextSecondary)
                    }

                    FlowLayout(spacing: 8) {
                        ForEach(deps.library.searchHistory, id: \.self) { keyword in
                            HGChip(title: keyword) {
                                query = keyword
                                search(keyword)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("热门题材", systemImage: "flame.fill")
                        .font(.headline)
                        .foregroundStyle(Color.hgText)
                    Spacer()
                    NavigationLink(value: Route.ranks) {
                        Text("完整榜单")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.hgPrimary)
                    }
                }

                FlowLayout(spacing: 8) {
                    ForEach(hotTags, id: \.self) { tag in
                        HGChip(title: tag) {
                            query = tag
                            search(tag)
                        }
                    }
                }
            }

            VStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.hgTextSecondary)
                Text("输入关键词搜索短剧")
                    .font(.headline)
                Text("也可以点题材标签直接看片单")
                    .font(.caption)
                    .foregroundStyle(Color.hgTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        }
    }

    // MARK: - 搜索结果

    @ViewBuilder
    private var results: some View {
        HStack {
            Text("「\(model.submitted)」")
                .font(.subheadline.weight(.semibold))
            Text("共 \(model.total) 条")
                .font(.caption)
                .foregroundStyle(Color.hgTextSecondary)
            Spacer()
            Button("收起") {
                model.clear()
                query = ""
            }
            .font(.caption)
            .foregroundStyle(Color.hgTextSecondary)
        }

        if model.items.isEmpty, model.isLoading {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 60)
        } else if model.items.isEmpty, let error = model.error {
            VStack(spacing: 12) {
                HGEmptyState(icon: "magnifyingglass", title: "搜索失败", message: error)
                Button("重试") {
                    Task { await model.retry() }
                }
                .buttonStyle(HGPrimaryButtonStyle())
            }
        } else if model.items.isEmpty {
            HGEmptyState(
                icon: "magnifyingglass",
                title: "没有找到相关内容",
                message: "换个关键词试试，比如「都市」「逆袭」"
            )
        } else {
            VideoPosterGrid(
                items: model.items,
                onOpen: open,
                onNearEnd: { id in
                    Task { await model.loadMoreIfNeeded(currentID: id) }
                }
            )
            footer
        }
    }

    private var footer: some View {
        Group {
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

    private func search(_ raw: String) {
        let keyword = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        focused = false
        Task { await model.submit(keyword) }
    }

    private func open(index: Int) {
        app.presentFeed(
            cards: model.items,
            index: index,
            title: "搜索 · \(model.submitted)",
            source: "search",
            page: model.page,
            pages: model.pages,
            query: model.submitted,
            library: deps.library
        )
    }
}

/// 简单的换行标签布局，避免为搜索历史引入额外依赖。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxX, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
