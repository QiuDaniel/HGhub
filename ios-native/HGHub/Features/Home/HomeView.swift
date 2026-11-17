import SwiftUI

struct HomeView: View {
    let deps: AppDependencies
    @State private var showContractCheck = false

    var body: some View {
        ZStack {
            Color.hgCanvas.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("HGhub")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                Text("原生 iOS · M0 骨架")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))

                #if DEBUG
                Button("M0 契约自检") {
                    showContractCheck = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.hgPrimary)
                .padding(.top, 10)
                #endif
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showContractCheck) {
            ContractCheckView(api: deps.api, videos: deps.videos)
        }
    }
}
