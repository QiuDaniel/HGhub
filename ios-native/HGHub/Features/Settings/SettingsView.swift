import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("M5 接入") {
                Text("主题 / 本地数据 / 清缓存 / 线路 / 网络诊断 / 检查更新")
            }
        }
        .navigationTitle("设置")
    }
}
