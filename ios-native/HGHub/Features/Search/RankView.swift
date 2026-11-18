import NukeUI
import SwiftUI

struct RankView: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @State private var model: RankViewModel

    init(deps: AppDependencies) {
        self.deps = deps
        _model = State(initialValue: RankViewModel(discovery: deps.discovery))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 10) {
                    if model.isLoading {
                        ProgressView()
                            .padding(.vertical, 70)
                    } else if let error = model.error {
                        VStack(spacing: 12) {
                            HGEmptyState(icon: "trophy", title: "榜单加载失败", message: error)
                            Button("重试") {
                                Task { await model.load() }
                            }
                            .buttonStyle(HGPrimaryButtonStyle())
                        }
                        .padding(.top, 40)
                    } else if model.items.isEmpty {
                        HGEmptyState(icon: "trophy", title: "榜单暂时为空", message: "稍后再来看看")
                            .padding(.top, 50)
                    } else {
                        ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                            Button {
                                open(index: index)
                            } label: {
                                RankRow(item: item, maximum: maximumMetric)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("rankRow_\(item.videoID)")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .background(Color.hgCanvas)
        .navigationTitle("榜单")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model.items.isEmpty {
                await model.load(kind: .hot)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.hgPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("HG 热榜")
                        .font(.title2.weight(.bold))
                    Text(model.kind.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.hgTextSecondary)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(RankKind.allCases) { kind in
                    Button {
                        Task { await model.select(kind) }
                    } label: {
                        Text(kind.title)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(kind == model.kind ? Color.hgOnPrimary : Color.hgTextSecondary)
                            .background(
                                kind == model.kind ? Color.hgPrimary : Color.hgSurface,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("rankTab_\(kind.rawValue)")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var maximumMetric: Int {
        max(1, model.items.map { $0.metricValue ?? 0 }.max() ?? 0)
    }

    private func open(index: Int) {
        let cards = model.items.map(\.card)
        app.presentFeed(
            cards: cards,
            index: index,
            title: "HG 热榜 · \(model.kind.title)",
            source: "rank",
            page: 1,
            pages: 1,
            library: deps.library
        )
    }
}

private struct RankRow: View {
    let item: RankItem
    let maximum: Int

    private var medalColor: Color {
        switch item.rank ?? 99 {
        case 1: return Color(red: 1.0, green: 0.78, blue: 0.28)
        case 2: return Color(red: 0.80, green: 0.84, blue: 0.90)
        case 3: return Color(red: 0.86, green: 0.55, blue: 0.32)
        default: return Color.hgTextSecondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(item.rank ?? 0)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(medalColor)
                .frame(width: 26)

            ZStack {
                Color.hgSurface2
                LazyImage(url: URL(string: item.cover ?? "")) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.hgSurface2
                    }
                }
                .scaledToFill()
            }
            .frame(width: 62, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.hgText)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let cate = item.cateName, !cate.isEmpty {
                        Text(cate)
                            .font(.caption2)
                            .foregroundStyle(Color.hgTextSecondary)
                    }
                    Text("\(item.episodeTotal) 集")
                        .font(.caption2)
                        .foregroundStyle(Color.hgTextSecondary)
                    if let score = item.score {
                        Text(String(format: "%.1f", score))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.hgPrimary)
                    }
                }

                if let tags = item.tags, !tags.isEmpty {
                    Text(tags.prefix(3).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(Color.hgTextSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.hgPrimary.opacity(0.18))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.hgPrimary)
                                    .frame(width: proxy.size.width * ratio)
                            }
                    }
                    .frame(height: 3)
                    .frame(maxWidth: 86)

                    Text(metricText)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.hgTextSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 13))
        .contentShape(Rectangle())
    }

    private var ratio: CGFloat {
        guard let value = item.metricValue, maximum > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maximum)
    }

    private var metricText: String {
        let label = item.metricLabel ?? ""
        let value = item.metricValue ?? 0
        return "\(label) \(compact(value))"
    }

    private func compact(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.1fw", Double(value) / 10_000)
        }
        return "\(value)"
    }
}
