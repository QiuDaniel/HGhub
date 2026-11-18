import SwiftUI
import UIKit

struct SettingsView: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @State private var linePicker = false
    @State private var showDiagnostics = false
    @State private var diagnostics: NetworkDiagnostics?
    @State private var diagnosticsLoading = false
    @State private var showAbout = false
    @State private var showClearCache = false
    @State private var showClearHistory = false
    @State private var clearingCache = false
    @State private var checkingUpdate = false
    @State private var update: UpdateInfo?

    var body: some View {
        Form {
            Section("外观") {
                Toggle("深色外观", isOn: darkBinding)
            }

            Section("本地数据") {
                LabeledContent("收藏", value: "\(deps.library.favorites.count)")
                LabeledContent("观看历史", value: "\(deps.library.history.count)")
                LabeledContent("搜索历史", value: "\(deps.library.searchHistory.count)")

                Button("清空观看历史", role: .destructive) {
                    showClearHistory = true
                }
                .disabled(deps.library.history.isEmpty)
                .accessibilityIdentifier("settingsClearHistory")
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
                .accessibilityIdentifier("settingsLines")

                Button {
                    runDiagnostics()
                } label: {
                    HStack {
                        Label("网络诊断", systemImage: "stethoscope")
                            .foregroundStyle(Color.hgText)
                        Spacer()
                        if diagnosticsLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .disabled(diagnosticsLoading)
                .accessibilityIdentifier("settingsDiagnostics")
            }

            Section("缓存") {
                Button {
                    showClearCache = true
                } label: {
                    HStack {
                        Label("清理缓存", systemImage: "trash")
                            .foregroundStyle(Color.hgText)
                        Spacer()
                        if clearingCache {
                            ProgressView()
                        }
                    }
                }
                .disabled(clearingCache)
                .accessibilityIdentifier("settingsClearCache")

                Text("清除封面图片和 URL 缓存，保留登录、收藏、观看历史与搜索历史。")
                    .font(.caption)
                    .foregroundStyle(Color.hgTextSecondary)
            }

            Section("关于") {
                LabeledContent("版本", value: appVersion)

                Button {
                    checkUpdate()
                } label: {
                    HStack {
                        Label("检查更新", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Color.hgText)
                        Spacer()
                        if checkingUpdate { ProgressView() }
                    }
                }
                .disabled(checkingUpdate)
                .accessibilityIdentifier("settingsCheckUpdate")

                Button("关于 HGhub / 免责声明") {
                    showAbout = true
                }
                .accessibilityIdentifier("settingsAbout")
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $linePicker) {
            LinePickerView(deps: deps)
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsSheet(diagnostics: diagnostics)
        }
        .sheet(isPresented: $showAbout) {
            AboutSheet(version: appVersion)
        }
        .sheet(item: $update) { info in
            UpdateSheet(info: info)
        }
        .confirmationDialog("清空观看历史？", isPresented: $showClearHistory, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                deps.library.clearHistory()
                app.showToast("观看历史已清空", icon: .ok)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只清空观看进度，收藏和登录状态会保留。")
        }
        .confirmationDialog("清理缓存？", isPresented: $showClearCache, titleVisibility: .visible) {
            Button("清理", role: .destructive) {
                clearCache()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只清除封面和网络缓存，不会清空收藏、历史与登录。")
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

    private func clearCache() {
        guard !clearingCache else { return }
        clearingCache = true
        Task {
            await deps.maintenance.clearCache()
            clearingCache = false
            app.showToast("缓存已清理", icon: .ok)
        }
    }

    private func runDiagnostics() {
        guard !diagnosticsLoading else { return }
        diagnosticsLoading = true
        Task {
            diagnostics = await deps.maintenance.diagnostics()
            diagnosticsLoading = false
            showDiagnostics = true
        }
    }

    private func checkUpdate() {
        guard !checkingUpdate else { return }
        checkingUpdate = true
        Task {
            defer { checkingUpdate = false }
            do {
                let info = try await deps.maintenance.checkUpdate()
                if info.hasUpdate {
                    update = info
                } else if info.latest.isEmpty {
                    app.showToast("还没有发布版本，当前 v\(info.current)", icon: .info)
                } else {
                    app.showToast("已是最新版本 v\(info.current)", icon: .ok)
                }
            } catch {
                app.showError(error)
            }
        }
    }
}

private struct DiagnosticsSheet: View {
    let diagnostics: NetworkDiagnostics?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(diagnostics?.displayText ?? "诊断中…")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .navigationTitle("网络诊断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("复制") {
                        UIPasteboard.general.string = diagnostics?.displayText
                    }
                    .disabled(diagnostics == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct AboutSheet: View {
    let version: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.hgPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HGhub")
                                .font(.title2.weight(.bold))
                            Text("原生 iOS 客户端 · v\(version)")
                                .font(.caption)
                                .foregroundStyle(Color.hgTextSecondary)
                        }
                    }

                    Text("本项目仅供个人学习与自用，所有内容均来自上游站点，客户端不存储、不分发任何视频内容。请于 24 小时内删除相关资源，并支持正版。")
                        .font(.subheadline)
                        .foregroundStyle(Color.hgTextSecondary)

                    Link("github.com/Minireel/HGhub", destination: URL(string: "https://github.com/Minireel/HGhub")!)
                        .font(.subheadline)
                    Link("huangguoai.com", destination: URL(string: "https://huangguoai.com")!)
                        .font(.subheadline)

                    Text("PolyForm Noncommercial 1.0.0 · 仅限非商业使用")
                        .font(.caption)
                        .foregroundStyle(Color.hgTextSecondary)
                }
                .padding(20)
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct UpdateSheet: View {
    let info: UpdateInfo

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("发现新版本")
                    .font(.title3.weight(.bold))
                Text("v\(info.current) → v\(info.latest)")
                    .font(.subheadline)
                    .foregroundStyle(Color.hgTextSecondary)
                if !info.notes.isEmpty {
                    ScrollView {
                        Text(info.notes)
                            .font(.caption)
                            .foregroundStyle(Color.hgTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                }
                Spacer()
                Link(destination: URL(string: info.url)!) {
                    Text("前往 GitHub 下载")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(Color.hgOnPrimary)
                        .background(Color.hgPrimary, in: Capsule())
                }
            }
            .padding(20)
            .navigationTitle("更新")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
