import NukeUI
import SwiftUI

/// 两列封面网格。首页 / 搜索 / 频道共用，保证卡片和点击行为一致。
struct VideoPosterGrid: View {
    let items: [VideoCard]
    let onOpen: (Int) -> Void
    var onNearEnd: ((Int) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, card in
                Button {
                    onOpen(index)
                } label: {
                    VideoCardCell(card: card)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("videoCard_\(card.id)")
                .task {
                    onNearEnd?(card.id)
                }
            }
        }
    }
}

struct VideoCardCell: View {
    let card: VideoCard

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomLeading) {
                Color.hgSurface2

                LazyImage(url: URL(string: card.cover ?? "")) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if state.error != nil {
                        Color.hgSurface2
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(Color.hgTextSecondary)
                            }
                    } else {
                        Color.hgSurface2
                            .overlay {
                                ProgressView()
                                    .controlSize(.small)
                            }
                    }
                }
                .scaledToFill()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.62)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: 6) {
                    Text("\(card.episodeTotal) 集")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45), in: Capsule())

                    Spacer(minLength: 0)

                    if let score = card.score {
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.hgPrimary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.45), in: Capsule())
                    }
                }
                .padding(8)
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(card.displayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.hgText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Text(card.authorName)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let hot = card.hot, hot > 0 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                    Text(hotText(hot))
                }
            }
            .font(.caption2)
            .foregroundStyle(Color.hgTextSecondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.displayTitle)，\(card.episodeTotal) 集")
    }

    private func hotText(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.1fw", Double(value) / 10_000)
        }
        return "\(value)"
    }
}
