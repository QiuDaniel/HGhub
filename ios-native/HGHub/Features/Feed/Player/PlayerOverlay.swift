import SwiftUI

struct PlayerOverlay: View {
    let state: PlayerState
    let card: VideoCard
    let episode: Int
    let isLiked: Bool
    let isFullscreen: Bool
    let scrubPreview: Double?
    let edgeHUD: String?

    var onClose: () -> Void
    var onTogglePlay: () -> Void
    var onLike: () -> Void
    var onComments: () -> Void
    var onEpisodes: () -> Void
    var onFullscreen: () -> Void
    var onMute: () -> Void
    var onRate: (Float) -> Void
    var onSeek: (Double) -> Void
    var onRetry: () -> Void

    @State private var dragFraction: Double?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                bottomBar
            }
            .overlay(alignment: .trailing) {
                sideBar
                    .padding(.bottom, 118)
            }

            centerStatus
            if let edgeHUD {
                Text(edgeHUD)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.5), in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 90)
                    .allowsHitTesting(false)
            }
            if let scrubPreview {
                scrubHUD(scrubPreview)
            }
            if let error = state.error {
                errorCard(error)
            }
        }
        .foregroundStyle(.white)
        .animation(.easeInOut(duration: 0.18), value: state.isPlaying)
        .animation(.easeInOut(duration: 0.18), value: state.error)
    }

    // MARK: - Top

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.32), in: Circle())
            }
            .accessibilityLabel("返回")
            .accessibilityIdentifier("feedClose")

            Text(card.displayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .shadow(radius: 3)

            Spacer(minLength: 4)

            Text("\(episode)/\(card.episodeTotal)")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.black.opacity(0.32), in: Capsule())

            Button(action: onMute) {
                Image(systemName: state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.32), in: Circle())
            }
            .accessibilityLabel(state.isMuted ? "取消静音" : "静音")
            .accessibilityIdentifier("playerMute")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .background {
            LinearGradient(
                colors: [.black.opacity(0.58), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Side

    private var sideBar: some View {
        VStack(spacing: 18) {
            sideButton(
                icon: isLiked ? "heart.fill" : "heart",
                tint: isLiked ? Color.hgPrimary : .white,
                label: compact(card.likeCount ?? 0),
                action: onLike
            )
            .accessibilityLabel(isLiked ? "取消喜欢" : "喜欢")
            .accessibilityIdentifier("playerLike")

            sideButton(
                icon: "text.bubble.fill",
                tint: .white,
                label: compact(card.commentCount ?? 0),
                action: onComments
            )
            .accessibilityLabel("评论")
            .accessibilityIdentifier("playerComments")

            sideButton(
                icon: "list.bullet.rectangle",
                tint: .white,
                label: "选集",
                action: onEpisodes
            )
            .accessibilityLabel("选集")
            .accessibilityIdentifier("playerEpisodes")

            sideButton(
                icon: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                tint: .white,
                label: "全屏",
                action: onFullscreen
            )
            .accessibilityLabel(isFullscreen ? "退出全屏" : "全屏")
            .accessibilityIdentifier("playerFullscreen")
        }
        .padding(.trailing, 12)
        .padding(.bottom, 118)
    }

    private func sideButton(icon: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(tint)
                    .shadow(radius: 3)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(radius: 2)
            }
            .frame(width: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.displayTitle)
                .font(.headline)
                .lineLimit(2)
                .shadow(radius: 3)

            HStack(spacing: 8) {
                Text("@\(card.authorName)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.86))
                Button(action: onEpisodes) {
                    Text("第 \(episode) 集")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.16), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("playerEpisodeBadge")
            }

            if let description = card.description, !description.isEmpty {
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }

            progressBar
                .padding(.top, 2)

            HStack(spacing: 10) {
                Text(state.duration > 0 ? state.timeText : "--:--")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Text("/")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                Text(state.durationText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Menu {
                    ForEach([Float(0.75), 1, 1.25, 1.5, 2], id: \.self) { value in
                        Button(value == 1 ? "1x" : "\(value.formatted())x") {
                            onRate(value)
                        }
                    }
                } label: {
                    Text(state.rate == 1 ? "1x" : "\(state.rate.formatted())x")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                .accessibilityLabel("倍速")
                .accessibilityIdentifier("playerRate")
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .background {
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let progress = min(max(dragFraction ?? state.progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.28))
                    .frame(height: 3)

                Capsule()
                    .fill(.white)
                    .frame(width: width * progress, height: 3)

                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .offset(x: max(width * progress - 5, 0))
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragFraction = min(max(value.location.x / width, 0), 1)
                    }
                    .onEnded { value in
                        let fraction = min(max(value.location.x / width, 0), 1)
                        onSeek(Double(fraction) * max(state.duration, 0))
                        dragFraction = nil
                    }
            )
        }
        .frame(height: 22)
        .accessibilityElement()
        .accessibilityLabel("进度")
        .accessibilityValue("\(state.timeText) / \(state.durationText)")
        .accessibilityIdentifier("playerProgress")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onSeek(state.time + 10)
            case .decrement:
                onSeek(state.time - 10)
            @unknown default:
                break
            }
        }
    }

    // MARK: - Center

    @ViewBuilder
    private var centerStatus: some View {
        if state.phase == .loading || (state.isBuffering && state.isPlaying) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.1)
                .allowsHitTesting(false)
        } else if state.isReady, !state.isPlaying, state.error == nil {
            Button(action: onTogglePlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 66)
                    .background(.black.opacity(0.42), in: Circle())
                    .overlay {
                        Circle().stroke(.white.opacity(0.18), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("播放")
            .accessibilityIdentifier("playerToggle")
        }
    }

    private func scrubHUD(_ fraction: Double) -> some View {
        let target = max(state.duration, 0) * max(0, min(fraction, 1))
        return VStack(spacing: 5) {
            Text(PlayerState.clock(target))
                .font(.system(size: 25, weight: .bold, design: .monospaced))
            Text("/ \(state.durationText)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .allowsHitTesting(false)
    }

    private func errorCard(_ error: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("视频暂时无法加载")
                .font(.headline)
            Text(error)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(4)
            Button("重试", action: onRetry)
                .buttonStyle(HGPrimaryButtonStyle())
                .accessibilityIdentifier("playerRetry")
        }
        .padding(20)
        .frame(maxWidth: 300)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))
    }

    private func compact(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.1fw", Double(value) / 10_000)
        }
        return "\(value)"
    }
}

/// 全屏仍然竖屏：只是铺满并隐藏 Feed chrome，复用同一个 AVPlayer。
struct PlayerFullscreenView: View {
    let coordinator: PlayerCoordinator
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PlayerSurface(player: coordinator.player)
                .ignoresSafeArea()

            if showControls {
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .bold))
                                .frame(width: 38, height: 38)
                                .background(.black.opacity(0.4), in: Circle())
                        }
                        .accessibilityLabel("关闭全屏")
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            coordinator.setMuted(!coordinator.state.isMuted)
                        } label: {
                            Image(systemName: coordinator.state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 38, height: 38)
                                .background(.black.opacity(0.4), in: Circle())
                        }
                        .accessibilityLabel(coordinator.state.isMuted ? "取消静音" : "静音")
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                    Spacer()

                    HStack(spacing: 12) {
                        Button {
                            coordinator.togglePlay()
                        } label: {
                            Image(systemName: coordinator.state.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.4), in: Circle())
                        }
                        .accessibilityLabel(coordinator.state.isPlaying ? "暂停" : "播放")

                        Text(coordinator.state.timeText)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        Text("/ \(coordinator.state.durationText)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        if coordinator.state.error != nil {
                            Button("重试") { coordinator.retry() }
                                .font(.caption.weight(.bold))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                    .background(.black.opacity(0.35))
                }
            }
        }
        .statusBarHidden()
        .onTapGesture {
            showControls.toggle()
        }
    }
}
