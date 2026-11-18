import SwiftUI

struct HomeView: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @State private var model: HomeViewModel
    @State private var showContractCheck = false

    init(deps: AppDependencies) {
        self.deps = deps
        _model = State(initialValue: HomeViewModel(videos: deps.videos))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header

                if model.isEmpty, model.isLoading {
                    loadingGrid
                } else if model.isEmpty, let error = model.error {
                    errorState(error)
                } else if model.isEmpty {
                    HGEmptyState(icon: "play.rectangle", title: "暂无视频", message: "下拉刷新，或稍后再来")
                } else {
                    grid
                    footer
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.hgCanvas)
        .scrollIndicators(.hidden)
        .refreshable {
            await model.refresh()
        }
        .task {
            await model.loadInitial()
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showContractCheck) {
            ContractCheckView(api: deps.api, videos: deps.videos)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("HGhub")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.hgText)
                Text(model.total > 0 ? "今日推荐 · \(model.total) 部" : "今日推荐")
                    .font(.caption)
                    .foregroundStyle(Color.hgTextSecondary)
            }

            Spacer()

            Menu {
                Button("M0 契约自检") {
                    showContractCheck = true
                }
                Button("刷新") {
                    Task { await model.refresh() }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(Color.hgText)
                    .frame(width: 36, height: 36)
                    .background(Color.hgSurface, in: Circle())
            }
            .accessibilityLabel("更多")
        }
        .padding(.top, 4)
    }

    // MARK: - Grid

    private var grid: some View {
        VideoPosterGrid(items: model.items, onOpen: { index in
            open(index: index)
        }, onNearEnd: { id in
            Task { await model.loadMoreIfNeeded(currentID: id) }
        })
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

    private var loadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.hgSurface2)
                        .aspectRatio(3 / 4, contentMode: .fit)
                    HGSkeleton(height: 13)
                    HGSkeleton(height: 10)
                        .frame(width: 80)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var footer: some View {
        Group {
            if model.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if !model.hasMore, !model.isEmpty {
                Text("已到底")
                    .font(.caption)
                    .foregroundStyle(Color.hgTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if let error = model.error {
                Button {
                    Task { await model.retry() }
                } label: {
                    Text("加载失败：\(error) · 重试")
                        .font(.caption)
                        .foregroundStyle(Color.hgPrimary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 12) {
            HGEmptyState(icon: "wifi.exclamationmark", title: "加载失败", message: error)
            Button("重试") {
                Task { await model.retry() }
            }
            .buttonStyle(HGPrimaryButtonStyle())
            .padding(.bottom, 40)
        }
    }

    private func open(index: Int) {
        guard model.items.indices.contains(index) else { return }
        let card = model.items[index]
        let history = deps.library.historyProgress(for: card.id)
        app.feed = FeedContext(
            cards: model.items,
            index: index,
            title: card.displayTitle,
            source: "home",
            startEp: history?.ep,
            startTime: history?.t,
            page: model.page,
            pages: model.pages
        )
    }
}
