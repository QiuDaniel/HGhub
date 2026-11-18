import SwiftUI

struct LinePickerView: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var selecting: String?

    private var fixed: [LineStore.Line] { LineStore.fixed }
    private var mirrors: [LineStore.Line] { deps.lineService.mirrors }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(fixed) { line in
                        lineRow(line)
                    }
                } header: {
                    HStack {
                        Text("固定线路")
                        Spacer()
                        Button("全部检测") {
                            Task {
                                await deps.lineService.probe(fixed.map(\.url) + mirrors.map(\.url))
                            }
                        }
                        .font(.caption)
                        .textCase(nil)
                        .disabled(deps.lineService.isProbing)
                    }
                }

                Section {
                    if deps.lineService.isLoadingMirrors, mirrors.isEmpty {
                        HStack {
                            ProgressView()
                            Text("正在获取镜像线路…")
                                .font(.caption)
                                .foregroundStyle(Color.hgTextSecondary)
                        }
                    } else if let error = deps.lineService.mirrorError, mirrors.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("镜像线路获取失败")
                                .font(.caption.weight(.semibold))
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(Color.hgTextSecondary)
                            Button("重试") {
                                Task { await deps.lineService.loadMirrors(force: true) }
                            }
                            .font(.caption)
                        }
                    } else if mirrors.isEmpty {
                        Text("暂无镜像线路")
                            .font(.caption)
                            .foregroundStyle(Color.hgTextSecondary)
                    } else {
                        ForEach(mirrors) { line in
                            lineRow(line)
                        }
                    }
                } header: {
                    HStack {
                        Text("镜像线路")
                        Spacer()
                        Button {
                            Task { await deps.lineService.loadMirrors(force: true) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(deps.lineService.isLoadingMirrors)
                        .accessibilityLabel("刷新镜像")
                    }
                } footer: {
                    Text("镜像来自 huangguoai.pages.dev，最多 60 条；检测只报告可达性，不会自动切换。")
                        .font(.caption2)
                }

                Section {
                    Text("切换线路会立即更新 APIClient base，下一次请求生效；进行中的请求不会被串线。")
                        .font(.caption)
                        .foregroundStyle(Color.hgTextSecondary)
                }
            }
            .navigationTitle("线路")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await deps.lineService.loadMirrors()
            }
        }
    }

    private func lineRow(_ line: LineStore.Line) -> some View {
        HStack(spacing: 8) {
            Button {
                select(line)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(line.name)
                            .foregroundStyle(Color.hgText)
                            .lineLimit(1)
                        if deps.lines.current.url == line.url {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.hgPrimary)
                        }
                    }
                    Text(line.url)
                        .font(.caption2)
                        .foregroundStyle(Color.hgTextSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(selecting != nil)

            if let probe = deps.lineService.probes[line.url] {
                Text(probe.display)
                    .font(.caption2)
                    .foregroundStyle(probe.ok ? Color.green : Color.red)
                    .frame(width: 56, alignment: .trailing)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(Color.hgTextSecondary)
                    .frame(width: 56, alignment: .trailing)
            }

            Button("检测") {
                Task { await deps.lineService.probe([line.url]) }
            }
            .font(.caption)
            .disabled(deps.lineService.isProbing)
            .accessibilityIdentifier("probe_\(line.url)")
        }
        .contentShape(Rectangle())
    }

    private func select(_ line: LineStore.Line) {
        guard selecting == nil else { return }
        selecting = line.url
        Task {
            let ok = await deps.lineService.select(line)
            selecting = nil
            if ok {
                app.showToast("已切换到 \(line.name)", icon: .ok)
                dismiss()
            } else {
                app.showToast("线路地址无效")
            }
        }
    }
}
