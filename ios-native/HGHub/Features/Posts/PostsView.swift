import SwiftUI

struct PostsView: View {
    var body: some View {
        HGEmptyState(
            icon: "text.bubble",
            title: "吃瓜",
            message: "M6 接入：列表、正文、互动"
        )
        .navigationTitle("吃瓜")
    }
}

struct PostDetailView: View {
    let id: Int

    var body: some View {
        HGEmptyState(
            icon: "doc.text",
            title: "帖子 \(id)",
            message: "M6 接入正文 HTML 与图片"
        )
        .navigationTitle("帖子")
    }
}
