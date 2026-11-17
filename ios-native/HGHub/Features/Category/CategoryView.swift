import SwiftUI

struct CategoryView: View {
    var body: some View {
        ContentUnavailableView(
            "分类",
            systemImage: "square.grid.2x2",
            description: Text("M4 接入：24 / 25 / 26 / 27 频道")
        )
        .navigationTitle("分类")
    }
}
