import SwiftUI

@main
struct HGHubApp: App {
    @State private var app = AppState()
    private let deps = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootTabView(deps: deps)
                .environment(app)
                .preferredColorScheme(app.theme == .dark ? .dark : .light)
                .overlay(alignment: .top) {
                    if let toast = app.toast {
                        Text(toast.message)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: app.toast?.id)
        }
    }
}
