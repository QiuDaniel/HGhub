import SwiftUI

struct LoginSheet: View {
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var loading = false
    @State private var errorText: String?
    @FocusState private var focus: Field?

    private enum Field {
        case username
        case password
    }

    private var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
            && !loading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("账号") {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .focused($focus, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                        .accessibilityIdentifier("loginUsername")

                    SecureField("密码", text: $password)
                        .textContentType(.password)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { submit() }
                        .accessibilityIdentifier("loginPassword")
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if loading {
                                ProgressView()
                            } else {
                                Text("登录")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("loginSubmit")

                    Text("登录后可点赞、收藏、关注和评论。账号由上游站点提供。")
                        .font(.caption)
                        .foregroundStyle(Color.hgTextSecondary)
                }
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        app.loginPresented = false
                        dismiss()
                    }
                }
            }
            .onAppear {
                focus = .username
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = password
        loading = true
        errorText = nil

        Task { @MainActor in
            defer { loading = false }
            do {
                let session = try await deps.account.login(username: name, password: secret)
                deps.session.set(token: session.token, user: session.user)
                await deps.api.setToken(session.token)
                app.apply(session: session)
                app.loginPresented = false
                app.showToast("登录成功", icon: .ok)
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
