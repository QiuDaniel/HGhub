import SwiftUI

struct PostCommentsSheet: View {
    let postID: Int
    let deps: AppDependencies
    let onRequireLogin: () -> Void
    let onSent: () -> Void

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var model: PostCommentsViewModel
    @State private var text = ""
    @State private var sending = false
    @FocusState private var focused: Bool

    init(
        postID: Int,
        deps: AppDependencies,
        onRequireLogin: @escaping () -> Void,
        onSent: @escaping () -> Void = {}
    ) {
        self.postID = postID
        self.deps = deps
        self.onRequireLogin = onRequireLogin
        self.onSent = onSent
        _model = State(initialValue: PostCommentsViewModel(
            postID: postID,
            repository: deps.posts
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("\(model.total) 条评论")
                            .font(.caption)
                            .foregroundStyle(Color.hgTextSecondary)
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                    if model.isEmpty, model.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 70)
                    } else if model.isEmpty, let error = model.error {
                        VStack(spacing: 12) {
                            Text("评论加载失败")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.hgTextSecondary)
                            Button("重试") {
                                Task { await model.loadInitial() }
                            }
                            .buttonStyle(HGSecondaryButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    } else if model.isEmpty {
                        HGEmptyState(icon: "text.bubble", title: "还没有评论", message: "来抢第一个沙发")
                            .frame(minHeight: 240)
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

    private var footer: some View {
        Group {
            if model.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else if model.hasMore {
                Button("查看更多") {
                    Task { await model.loadMore() }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.hgPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                Text("— 到底啦 —")
                    .font(.caption2)
                    .foregroundStyle(Color.hgTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
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
            .accessibilityIdentifier("postCommentLogin")
        } else {
            HStack(spacing: 8) {
                HGAvatar(name: app.session?.user?.nickname ?? "我", size: 30)
                TextField("说点什么…", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.hgSurface, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("postCommentInput")

                Button {
                    send()
                } label: {
                    if sending {
                        ProgressView().frame(width: 34, height: 34)
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
                .accessibilityIdentifier("postCommentSend")
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
                focused = false
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
