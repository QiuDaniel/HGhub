import SwiftUI

struct SearchView: View {
    var body: some View {
        HGEmptyState(
            icon: "magnifyingglass",
            title: "搜索",
            message: "M4 接入：关键词、搜索历史、榜单"
        )
        .navigationTitle("搜索")
    }
}

struct RankView: View {
    var body: some View {
        HGEmptyState(
            icon: "chart.bar",
            title: "榜单",
            message: "M4 接入：热门 / 推荐 / 潜力"
        )
        .navigationTitle("榜单")
    }
}
