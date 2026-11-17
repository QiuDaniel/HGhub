import SwiftUI

/// M1 只做登录壳：真实登录、注册、退出与 401 处理在 M3 接入。
struct LoginSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("账号") {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $password)
                }

                Section {
                    Button("登录") {
                        app.showToast("登录在 M3 接入")
                    }
                    .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)

                    Text("M3 接入：登录 / 注册 / 退出 / 401 统一处理。")
                        .font(.caption)
                        .foregroundStyle(Color.hgTextSecondary)
                }
            }
            .navigationTitle("登录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
