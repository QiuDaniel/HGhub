import SwiftUI

struct LinePickerView: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("固定线路") {
                    ForEach(LineStore.fixed) { line in
                        Button {
                            select(line)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.name)
                                        .foregroundStyle(Color.hgText)
                                    Text(line.url)
                                        .font(.caption2)
                                        .foregroundStyle(Color.hgTextSecondary)
                                }
                                Spacer()
                                if deps.lines.current.url == line.url {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.hgPrimary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Text("镜像线路、发布页解析与探测在 M5 接入。")
                        .font(.caption)
                        .foregroundStyle(Color.hgTextSecondary)
                }
            }
            .navigationTitle("线路")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func select(_ line: LineStore.Line) {
        guard deps.lines.select(line) else {
            app.showToast("线路地址无效")
            return
        }
        let url = deps.lines.currentURL
        Task {
            await deps.api.setBase(url)
        }
        app.showToast("已切换到 \(line.name)", icon: .ok)
        dismiss()
    }
}
