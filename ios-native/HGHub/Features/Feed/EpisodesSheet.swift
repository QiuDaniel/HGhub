import SwiftUI

struct EpisodesSheet: View {
    let card: VideoCard
    let current: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 58), spacing: 10),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(1...card.episodeTotal, id: \.self) { ep in
                        Button {
                            onSelect(ep)
                            dismiss()
                        } label: {
                            Text("\(ep)")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .foregroundStyle(ep == current ? Color.hgOnPrimary : Color.hgText)
                                .background(
                                    ep == current ? Color.hgPrimary : Color.hgSurface,
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("episode_\(ep)")
                    }
                }
                .padding(16)
            }
            .navigationTitle("选集 · \(card.displayTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
