import SwiftUI

struct CommentsSheet: View {
    let card: VideoCard
    let ep: Int
    let deps: AppDependencies
    let onRequireLogin: () -> Void
    let onSent: () -> Void

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var model: CommentsViewModel
    @State private var text = ""
    @State private var sending = false
    @FocusState private var inputFocused: Bool

    init(
        card: VideoCard,
        ep: Int,
        deps: AppDependencies,
        onRequireLogin: @escaping () -> Void,
        onSent: @escaping () -> Void = {}
    ) {
        self.card = card
        self.ep = ep
        self.deps = deps
        self.onRequireLogin = onRequireLogin
        self.onSent = onSent
        _model = State(
            initialValue: CommentsViewModel(videoID: card.id, ep: ep, social: deps.social)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header

                    if model.isEmpty, model.isLoading {
                        loadingState
                    } else if model.isEmpty, let error = model.error {
                        errorState(error)
                    } else if model.isEmpty {
                        HGEmptyState(icon: "text.bubble", title: "还没有评论", message: "来抢第一个沙发")
                            .frame(minHeight: 260)
                    } else {
                        ForEach(model.items) { comment in
                            CommentRow(comment: comment)
                                .task {
                                    await model.loadMoreIfNeeded(currentID: comment.id)
                                }
                        }
                        footer
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.hgCanvas)
            .navigationTitle("评论")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                composer
            }
            .task {
                await model.loadInitial()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("第 \(ep) 集")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.hgSurface, in: Capsule())
            Text("\(model.total) 条评论")
                .font(.caption)
                .foregroundStyle(Color.hgTextSecondary)
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("加载评论…")
                .font(.caption)
                .foregroundStyle(Color.hgTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 12) {
            Text("评论加载失败")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(Color.hgTextSecondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await model.loadInitial() }
            }
            .buttonStyle(HGSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var footer: some View {
        Group {
            if model.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if model.hasMore {
                Button("查看更多") {
                    Task { await model.loadMore() }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.hgPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                Text("— 到底啦 —")
                    .font(.caption2)
                    .foregroundStyle(Color.hgTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }

    @ViewBuilder
    private var composer: some View {
        if app.session == nil {
            Button {
                onRequireLogin()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("登录后参与评论")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.hgPrimary)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(.regularMaterial)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("commentLogin")
        } else {
            HStack(spacing: 8) {
                HGAvatar(name: app.session?.user?.nickname ?? "我", size: 30)

                TextField("说点什么…", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("commentInput")

                Button {
                    send()
                } label: {
                    if sending {
                        ProgressView()
                            .frame(width: 34, height: 34)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.hgTextSecondary : Color.hgOnPrimary)
                            .frame(width: 34, height: 34)
                            .background(
                                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.hgSurface
                                    : Color.hgPrimary,
                                in: Circle()
                            )
                    }
                }
                .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("commentSend")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
        }
    }

    private func send() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !sending else { return }

        guard app.session != nil else {
            onRequireLogin()
            return
        }

        sending = true
        Task { @MainActor in
            defer { sending = false }
            do {
                try await model.send(text: body)
                text = ""
                inputFocused = false
                onSent()
                app.showToast("评论已提交，审核通过后展示", icon: .ok)
            } catch let error as APIError {
                if case .unauthorized = error {
                    await deps.handleUnauthorized(app: app)
                    onRequireLogin()
                } else {
                    app.showError(error)
                }
            } catch {
                app.showError(error)
            }
        }
    }
}

struct CommentRow: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HGAvatar(name: comment.displayName, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.hgText)
                    if comment.isPinned == true {
                        Text("置顶")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.hgPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.hgPrimary.opacity(0.14), in: Capsule())
                    }
                    Spacer(minLength: 0)
                    Text(comment.displayTime)
                        .font(.caption2)
                        .foregroundStyle(Color.hgTextSecondary)
                }

                Text(comment.displayText)
                    .font(.subheadline)
                    .foregroundStyle(Color.hgText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Label("\(comment.likeCount ?? 0)", systemImage: "heart")
                    if let replies = comment.replyCount, replies > 0 {
                        Label("\(replies)", systemImage: "bubble.left")
                    }
                    if let region = comment.ipRegion, !region.isEmpty {
                        Text(region)
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.hgTextSecondary)

                if let reply = comment.replies.first {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(reply.displayName)：\(reply.displayText)")
                            .font(.caption)
                            .foregroundStyle(Color.hgTextSecondary)
                            .lineLimit(2)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color.hgSeparator)
        }
        .accessibilityElement(children: .combine)
    }
}
