import SwiftUI

struct SearchView: View {
    var body: some View {
        ContentUnavailableView(
            "搜索",
            systemImage: "magnifyingglass",
            description: Text("M4 接入：关键词、搜索历史、榜单")
        )
        .navigationTitle("搜索")
    }
}

struct RankView: View {
    var body: some View {
        ContentUnavailableView(
            "榜单",
            systemImage: "chart.bar",
            description: Text("M4 接入：热门 / 推荐 / 潜力")
        )
        .navigationTitle("榜单")
    }
}
