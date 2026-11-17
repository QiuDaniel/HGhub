import Observation
import SwiftUI

@MainActor
@Observable
final class ContractCheckModel {
    var lines: [String] = []
    var running = false

    func run(_ block: @escaping @Sendable () async throws -> String) {
        guard !running else { return }
        running = true
        lines.append("…")
        let index = lines.count - 1

        Task { @MainActor in
            defer { running = false }
            do {
                let result = try await block()
                if lines.indices.contains(index) {
                    lines[index] = "✅ \(result)"
                }
            } catch {
                if lines.indices.contains(index) {
                    lines[index] = "❌ \(error.localizedDescription)"
                }
            }
        }
    }
}

/// M0 冒烟页：只验证「信封 / 解析 / 播放地址」链路，不承载业务 UI。
/// 入口在 Debug 首页；Release 下不显示按钮。
struct ContractCheckView: View {
    let api: APIClient
    let videos: VideoRepository

    @Environment(\.dismiss) private var dismiss
    @State private var model = ContractCheckModel()

    var body: some View {
        NavigationStack {
            List {
                Section("请求") {
                    Button("Boot / 当前线路") { boot() }
                        .disabled(model.running)
                    Button("Feed 第 1 页") { feed() }
                        .disabled(model.running)
                    Button("Playback 117 / 第 3 集") { playback() }
                        .disabled(model.running)
                }

                Section("输出") {
                    if model.lines.isEmpty {
                        Text("还没有结果")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("M0 契约自检")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("清空") { model.lines.removeAll() }
                        .disabled(model.running || model.lines.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .overlay {
                if model.running {
                    ProgressView()
                        .padding(18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func boot() {
        model.run {
            let base = await api.currentBase
            return "base = \(base.absoluteString)"
        }
    }

    private func feed() {
        model.run {
            let page = try await videos.feed(page: 1, size: 10)
            let first = page.items.first?.title ?? "-"
            return "items=\(page.items.count) total=\(page.pagination.total) first=\(first)"
        }
    }

    private func playback() {
        model.run {
            let info = try await videos.playback(id: 117, ep: 3)
            return "url=\(info.videoURL.prefix(90))"
        }
    }
}
