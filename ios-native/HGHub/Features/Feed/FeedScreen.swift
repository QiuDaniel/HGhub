import SwiftUI
import UIKit

struct FeedScreen: View {
    let context: FeedContext
    let deps: AppDependencies

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var model: FeedViewModel
    @State private var player: PlayerCoordinator
    @State private var interactions: FeedInteractionModel
    @State private var currentEp: Int
    @State private var didStart = false
    @State private var sheet: FeedSheet?
    @State private var isFullscreen = false
    @State private var scrubPreview: Double?
    @State private var scrubBaseTime: Double = 0
    @State private var edgeHUD: String?
    @State private var edgeStartValue: Float = 0
    @State private var edgeKind: FeedPager.Edge?
    @State private var lastRecordedTime: Double = 0
    @State private var rateBeforeLongPress: Float = 1

    init(context: FeedContext, deps: AppDependencies) {
        self.context = context
        self.deps = deps
        _model = State(initialValue: FeedViewModel(context: context, videos: deps.videos))
        _player = State(initialValue: PlayerCoordinator(videos: deps.videos))
        _currentEp = State(initialValue: max(context.startEp ?? 1, 1))
        let firstCard = context.cards.indices.contains(context.index) ? context.cards[context.index] : nil
        _interactions = State(
            initialValue: FeedInteractionModel(
                card: firstCard,
                ep: max(context.startEp ?? 1, 1),
                social: deps.social,
                library: deps.library
            )
        )
    }

    private var card: VideoCard? { model.current }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if model.cards.isEmpty {
                emptyState
            } else {
                FeedPager(
                    cards: model.cards,
                    index: $model.index,
                    onTap: {
                        player.togglePlay()
                    },
                    onDoubleTap: {
                        toggleLike()
                    },
                    onLongPressChanged: { active in
                        if active {
                            rateBeforeLongPress = player.state.rate
                            player.setRate(2)
                        } else {
                            player.setRate(rateBeforeLongPress)
                        }
                    },
                    onScrubBegan: {
                        scrubBaseTime = player.state.time
                        scrubPreview = player.state.progress
                    },
                    onScrubChanged: { fraction in
                        guard player.state.duration > 0 else { return }
                        let target = scrubBaseTime + fraction * player.state.duration
                        scrubPreview = min(max(target / player.state.duration, 0), 1)
                    },
                    onScrubEnded: { fraction in
                        guard player.state.duration > 0 else {
                            scrubPreview = nil
                            return
                        }
                        player.seek(to: scrubBaseTime + fraction * player.state.duration)
                        scrubPreview = nil
                    },
                    onEdgeBegan: { kind in
                        edgeKind = kind
                        edgeStartValue = kind == .brightness
                            ? Float(UIScreen.main.brightness)
                            : player.state.volume
                    },
                    onEdgeChanged: { delta in
                        adjustEdge(delta)
                    },
                    onEdgeEnded: {
                        edgeHUD = nil
                        edgeKind = nil
                    },
                    onNearEnd: { index in
                        Task { await model.loadMoreIfNeeded(at: index) }
                    }
                )
                .ignoresSafeArea()

                if let card {
                    PlayerSurface(player: player.player)
                        .opacity(player.state.isReady ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: player.state.isReady)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    PlayerOverlay(
                        state: player.state,
                        card: card,
                        episode: currentEp,
                        isLiked: interactions.liked,
                        likeCount: interactions.likeCount,
                        isFullscreen: false,
                        scrubPreview: scrubPreview,
                        edgeHUD: edgeHUD,
                        onClose: { dismiss() },
                        onTogglePlay: { player.togglePlay() },
                        onLike: { toggleLike() },
                        onComments: { sheet = .comments },
                        onDetail: { sheet = .detail },
                        onEpisodes: { sheet = .episodes },
                        onFullscreen: { isFullscreen = true },
                        onMute: { player.setMuted(!player.state.isMuted) },
                        onRate: { player.setRate($0) },
                        onSeek: { player.seek(to: $0) },
                        onRetry: { player.retry() }
                    )
                }
            }
        }
        .statusBarHidden()
        .task {
            startIfNeeded()
        }
        .onChange(of: model.index) { _, _ in
            syncCurrent()
        }
        .onChange(of: player.state.time) { _, _ in
            recordProgress()
        }
        .onChange(of: player.state.isPlaying) { _, playing in
            if !playing {
                recordProgress(force: true)
            }
        }
        .onChange(of: player.state.ended) { _, ended in
            guard ended else { return }
            player.state.ended = false
            advanceAfterEnd()
        }
        .onDisappear {
            guard !isFullscreen else { return }
            recordProgress(force: true)
            player.stop()
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            if let card {
                PlayerFullscreenView(coordinator: player, title: card.displayTitle)
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .episodes:
                if let card {
                    EpisodesSheet(card: card, current: currentEp) { ep in
                        changeEpisode(ep)
                    }
                }
            case .comments:
                if let card {
                    CommentsSheet(
                        card: card,
                        ep: currentEp,
                        deps: deps,
                        onRequireLogin: requestLogin,
                        onSent: { interactions.noteCommentSent() }
                    )
                }
            case .detail:
                DetailSheet(
                    interactions: interactions,
                    deps: deps,
                    onSelectEpisode: { ep in
                        changeEpisode(ep)
                    },
                    onRequireLogin: requestLogin
                )
            }
        }
        .sheet(isPresented: loginBinding) {
            LoginSheet(deps: deps)
        }
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { app.loginPresented },
            set: { app.loginPresented = $0 }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            HGEmptyState(icon: "play.slash", title: "没有可播放的视频", message: "返回首页刷新后再试")
            Button("返回") { dismiss() }
                .buttonStyle(HGPrimaryButtonStyle())
        }
    }

    // MARK: - Lifecycle

    private func startIfNeeded() {
        guard !didStart, let card else { return }
        didStart = true
        let history = deps.library.historyProgress(for: card.id)
        let ep = max(context.startEp ?? history?.ep ?? 1, 1)
        let time = max(context.startTime ?? history?.t ?? 0, 0)
        currentEp = ep
        lastRecordedTime = time
        interactions.configure(card: card, ep: ep)
        player.play(videoID: card.id, ep: ep, startTime: time)
        preloadNext()
    }

    private func syncCurrent() {
        guard didStart, let card else { return }
        recordProgress(force: true)

        let history = deps.library.historyProgress(for: card.id)
        let ep = max(history?.ep ?? 1, 1)
        let time = max(history?.t ?? 0, 0)
        currentEp = ep
        lastRecordedTime = time
        interactions.configure(card: card, ep: ep)
        player.play(videoID: card.id, ep: ep, startTime: time)
        preloadNext()
    }

    private func changeEpisode(_ ep: Int) {
        guard let card else { return }
        let next = min(max(ep, 1), card.episodeTotal)
        recordProgress(force: true)
        currentEp = next
        lastRecordedTime = 0
        interactions.configure(card: card, ep: next)
        player.play(videoID: card.id, ep: next, startTime: 0)
        preloadNext()
    }

    private func advanceAfterEnd() {
        guard let card else { return }
        if currentEp < card.episodeTotal {
            changeEpisode(currentEp + 1)
        } else if model.index + 1 < model.cards.count {
            model.index += 1
        }
    }

    // MARK: - Actions

    private func preloadNext() {
        guard model.index + 1 < model.cards.count else { return }
        let next = model.cards[model.index + 1]
        let history = deps.library.historyProgress(for: next.id)
        player.preload(videoID: next.id, ep: max(history?.ep ?? 1, 1))
    }

    private func toggleLike() {
        guard requireLogin() else { return }
        Task {
            let outcome = await interactions.toggleLike()
            await handle(outcome, success: interactions.liked ? "已点赞" : "已取消点赞")
        }
    }

    private func requireLogin() -> Bool {
        if app.session != nil { return true }
        requestLogin()
        return false
    }

    private func requestLogin() {
        if sheet != nil {
            // 401 可能已经把 loginPresented 置 true；先归零，等当前 sheet 退场再弹。
            app.loginPresented = false
            sheet = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                app.loginPresented = true
            }
        } else {
            app.loginPresented = true
        }
    }

    private func handle(_ outcome: InteractionOutcome, success: String) async {
        switch outcome {
        case .ok:
            app.showToast(success, icon: .heart)
        case .needsLogin:
            requestLogin()
        case .unauthorized:
            await deps.handleUnauthorized(app: app)
            requestLogin()
        case .failed(let message):
            app.showToast(message)
        }
    }

    private func adjustEdge(_ delta: Double) {
        guard let edgeKind else { return }
        let value = Float(min(max(Double(edgeStartValue) + delta, 0), 1))
        switch edgeKind {
        case .brightness:
            UIScreen.main.brightness = CGFloat(value)
            edgeHUD = "亮度 \(Int(value * 100))%"
        case .volume:
            player.setVolume(value)
            edgeHUD = "音量 \(Int(value * 100))%"
        }
    }

    private func recordProgress(force: Bool = false) {
        guard let id = player.state.currentID,
              let ep = player.state.currentEp,
              player.state.time > 0 else { return }

        let time = player.state.time
        guard force || abs(time - lastRecordedTime) >= 5 else { return }
        deps.library.recordHistory(
            id: id,
            ep: ep,
            time: time,
            duration: player.state.duration
        )
        lastRecordedTime = time
    }
}

private enum FeedSheet: String, Identifiable {
    case episodes
    case comments
    case detail

    var id: String { rawValue }
}
