import SwiftUI

struct PostsView: View {
    var body: some View {
        ContentUnavailableView(
            "吃瓜",
            systemImage: "text.bubble",
            description: Text("M6 接入：列表、正文、互动")
        )
        .navigationTitle("吃瓜")
    }
}
