import AVKit
import SwiftUI

struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = true
        view.tintColor = .white
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        view.accessibilityLabel = "AirPlay"
        view.accessibilityIdentifier = "playerAirPlay"
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {
        view.tintColor = .white
    }
}

struct AirPlayTile: View {
    var body: some View {
        VStack(spacing: 3) {
            AirPlayRouteButton()
                .frame(width: 25, height: 25)
            Text("投屏")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(radius: 2)
        }
        .frame(width: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AirPlay 投屏")
    }
}
