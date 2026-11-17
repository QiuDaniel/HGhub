import SwiftUI

struct CategoryView: View {
    var body: some View {
        HGEmptyState(
            icon: "square.grid.2x2",
            title: "分类",
            message: "M4 接入：24 / 25 / 26 / 27 频道"
        )
        .navigationTitle("分类")
    }
}

struct ChannelView: View {
    let cate: String
    let name: String

    var body: some View {
        HGEmptyState(
            icon: "square.grid.2x2",
            title: name,
            message: "频道 \(cate) · M4 接入列表"
        )
        .navigationTitle(name)
    }
}
