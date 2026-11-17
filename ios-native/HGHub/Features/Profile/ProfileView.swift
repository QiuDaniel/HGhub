import SwiftUI

struct ProfileView: View {
    var body: some View {
        ContentUnavailableView(
            "我的",
            systemImage: "person",
            description: Text("M5 接入：资料卡、收藏、观看历史")
        )
        .navigationTitle("我的")
    }
}
