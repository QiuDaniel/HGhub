import SwiftUI

struct SettingsView: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @State private var linePicker = false

    var body: some View {
        Form {
            Section("外观") {
                Toggle("深色外观", isOn: darkBinding)
            }

            Section("本地数据") {
                LabeledContent("收藏", value: "\(deps.library.favorites.count)")
                LabeledContent("观看历史", value: "\(deps.library.history.count)")
                Button("清空观看历史", role: .destructive) {
                    deps.library.clearHistory()
                    app.showToast("观看历史已清空", icon: .ok)
                }
                .disabled(deps.library.history.isEmpty)
            }

            Section("网络") {
                Button {
                    linePicker = true
                } label: {
                    HStack {
                        Label("线路", systemImage: "network")
                            .foregroundStyle(Color.hgText)
                        Spacer()
                        Text(LineStore.host(of: deps.lines.current.url) ?? deps.lines.current.url)
                            .foregroundStyle(Color.hgTextSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section("关于") {
                LabeledContent("版本", value: appVersion)
                Text("M5 接入：清缓存、网络诊断、检查更新与镜像线路。")
                    .font(.caption)
                    .foregroundStyle(Color.hgTextSecondary)
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $linePicker) {
            LinePickerView(deps: deps)
        }
    }

    private var darkBinding: Binding<Bool> {
        Binding(
            get: { app.theme == .dark },
            set: { app.theme = $0 ? .dark : .light }
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}
