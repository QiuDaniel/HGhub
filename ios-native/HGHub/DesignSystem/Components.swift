import SwiftUI

// MARK: - Buttons

struct HGPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .foregroundStyle(Color.hgOnPrimary)
            .background(Color.hgPrimary, in: Capsule())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct HGSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundStyle(Color.hgText)
            .background(Color.hgSurface, in: Capsule())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

// MARK: - Chip

struct HGChip: View {
    let title: String
    var selected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Color.hgPrimary : Color.hgTextSecondary)
                .background(
                    selected ? Color.hgPrimary.opacity(0.16) : Color.hgSurface,
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(
                            selected ? Color.hgPrimary.opacity(0.45) : Color.hgSeparator,
                            lineWidth: 0.5
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Avatar

struct HGAvatar: View {
    let name: String
    var size: CGFloat = 36

    private var initial: String {
        name.first.map(String.init) ?? "?"
    }

    private var hue: Double {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(sum % 360) / 360
    }

    var body: some View {
        Circle()
            .fill(Color(hue: hue, saturation: 0.55, brightness: 0.85))
            .frame(width: size, height: size)
            .overlay {
                Text(initial)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
}

// MARK: - Section / Empty / Skeleton

struct HGSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.hgText)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.hgTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HGEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.hgTextSecondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.hgText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.hgTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct HGSkeleton: View {
    var height: CGFloat = 14
    @State private var dim = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.hgSurface2)
            .frame(height: height)
            .opacity(dim ? 0.45 : 0.9)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    dim = true
                }
            }
    }
}
