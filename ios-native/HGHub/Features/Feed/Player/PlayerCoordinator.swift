import AVFoundation
import AVKit
import Defaults
import Foundation
import MediaPlayer
import Observation
import UIKit

/// 整个 Feed 只创建一个 AVPlayer；翻页/切集只 replaceCurrentItem。
@MainActor
@Observable
final class PlayerCoordinator: NSObject {
    private static let mutedKey = Defaults.Key<Bool>("hghub_player_muted", default: true)

    let player = AVPlayer()
    let state = PlayerState()

    @ObservationIgnored private lazy var pipLayer = AVPlayerLayer(player: player)
    @ObservationIgnored private var pipController: AVPictureInPictureController?
    private(set) var isPiPActive = false
    private var nowTitle = "HGhub"
    private var nowSubtitle = ""

    private let videos: VideoRepository
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var loadTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?
    private var infoCache: [String: PlayInfo] = [:]
    private var generation = 0
    private var request: (id: Int, ep: Int, startTime: Double)?
    private var pausedByUser = false

    init(videos: VideoRepository) {
        self.videos = videos
        super.init()
        state.isMuted = Defaults[Self.mutedKey]
        player.isMuted = state.isMuted
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [])
        try? session.setActive(true)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.handleTick(time)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.state.ended = true
                self?.state.isPlaying = false
                self?.state.phase = .paused
                self?.refreshNowPlaying()
            }
        }

        configureRemoteCommands()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        refreshNowPlaying()
    }

    // MARK: - Playback

    func play(videoID: Int, ep: Int, startTime: Double = 0) {
        generation += 1
        let run = generation
        loadTask?.cancel()
        request = (videoID, ep, max(startTime, 0))
        pausedByUser = false
        state.resetForLoad(id: videoID, ep: ep)
        state.rate = max(state.rate, 0.5)

        loadTask = Task { @MainActor [weak self] in
            await self?.load(videoID: videoID, ep: ep, startTime: startTime, generation: run)
        }
    }

    func retry() {
        guard let request else { return }
        play(videoID: request.id, ep: request.ep, startTime: request.startTime)
    }

    /// 只预取下一条的播放信息与 asset，不创建第二个 AVPlayer。
    func preload(videoID: Int, ep: Int) {
        guard videoID != state.currentID else { return }
        preloadTask?.cancel()
        preloadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let info = try await self.playInfo(id: videoID, ep: ep)
                guard !Task.isCancelled, let url = URL(string: info.videoURL) else { return }
                let asset = AVURLAsset(url: url)
                _ = try await asset.load(.isPlayable)
            } catch {
                // 预加载失败不打扰当前播放，真正切条时会再走错误态。
            }
        }
    }

    func togglePlay() {
        guard state.isReady else {
            if state.phase == .failed { retry() }
            return
        }
        if player.timeControlStatus == .playing {
            player.pause()
            pausedByUser = true
            state.isPlaying = false
            state.phase = .paused
        } else {
            player.play()
            player.rate = state.rate
            pausedByUser = false
            state.isPlaying = true
            state.phase = .playing
        }
        refreshNowPlaying()
    }

    func updateMetadata(title: String, subtitle: String) {
        nowTitle = title
        nowSubtitle = subtitle
        refreshNowPlaying()
    }

    // MARK: - PiP / AirPlay

    var isPiPSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    func togglePiP() {
        guard isPiPSupported else { return }
        if pipController == nil {
            let controller = AVPictureInPictureController(playerLayer: pipLayer)
            controller?.delegate = self
            pipController = controller
            pipLayer.player = player
        }
        guard let pipController else { return }
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
        } else if pipController.isPictureInPicturePossible {
            pipController.startPictureInPicture()
        }
    }

    func setRate(_ rate: Float) {
        state.rate = rate
        if player.timeControlStatus == .playing {
            player.rate = rate
        }
    }

    func setMuted(_ muted: Bool) {
        state.isMuted = muted
        player.isMuted = muted
        Defaults[Self.mutedKey] = muted
        if !muted {
            // 用户主动开启声音时顺手激活音频会话，避免后台/来电后停留在静默。
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    func setVolume(_ volume: Float) {
        let value = min(max(volume, 0), 1)
        state.volume = value
        player.volume = value
        if value > 0, state.isMuted {
            setMuted(false)
        }
    }

    func seek(to seconds: Double) {
        guard state.isReady, seconds.isFinite else { return }
        let target = min(max(seconds, 0), max(state.duration, 0))
        state.time = target
        let time = CMTime(seconds: target, preferredTimescale: 600)
        Task { @MainActor [weak self] in
            await self?.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func seek(byFraction fraction: Double) {
        guard state.duration > 0 else { return }
        seek(to: state.time + fraction * state.duration)
    }

    func stop() {
        generation += 1
        loadTask?.cancel()
        loadTask = nil
        preloadTask?.cancel()
        preloadTask = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        request = nil
        pausedByUser = false
        state.clear()
    }

    // MARK: - Loading

    private func load(videoID: Int, ep: Int, startTime: Double, generation: Int) async {
        do {
            let info = try await playInfo(id: videoID, ep: ep)
            guard generation == self.generation, !Task.isCancelled else { return }
            guard let url = URL(string: info.videoURL) else {
                throw APIError.invalidURL
            }

            let item = AVPlayerItem(url: url)
            item.preferredForwardBufferDuration = 5
            player.replaceCurrentItem(with: item)

            try await waitUntilReady(item, generation: generation)

            guard generation == self.generation, !Task.isCancelled else { return }

            if startTime > 0 {
                let target = CMTime(seconds: startTime, preferredTimescale: 600)
                await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
            }

            updateDuration()
            player.play()
            player.rate = state.rate
            player.isMuted = state.isMuted
            player.volume = state.volume
            pausedByUser = false
            state.isReady = true
            state.isBuffering = false
            state.isPlaying = true
            state.phase = .playing
            refreshNowPlaying()
        } catch is CancellationError {
            return
        } catch {
            guard generation == self.generation else { return }
            state.isReady = false
            state.isBuffering = false
            state.isPlaying = false
            state.phase = .failed
            state.error = error.localizedDescription
        }
    }

    private func playInfo(id: Int, ep: Int) async throws -> PlayInfo {
        let key = "\(id)-\(ep)"
        if let cached = infoCache[key] { return cached }
        let info = try await videos.playback(id: id, ep: ep)
        if infoCache.count >= 6 { infoCache.removeAll() }
        infoCache[key] = info
        return info
    }

    private func waitUntilReady(_ item: AVPlayerItem, generation: Int) async throws {
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            guard generation == self.generation, !Task.isCancelled else {
                throw CancellationError()
            }
            switch item.status {
            case .readyToPlay:
                return
            case .failed:
                throw APIError.business(item.error?.localizedDescription ?? "视频加载失败")
            case .unknown:
                try await Task.sleep(for: .milliseconds(80))
            @unknown default:
                throw APIError.business("视频状态未知")
            }
        }
        throw APIError.timeout
    }

    private func refreshNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: state.time,
            MPMediaItemPropertyPlaybackDuration: max(state.duration, 0),
            MPNowPlayingInfoPropertyPlaybackRate: state.isPlaying ? Double(state.rate) : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(state.rate),
        ]
        if !nowSubtitle.isEmpty {
            info[MPMediaItemPropertyArtist] = nowSubtitle
        }
        center.nowPlayingInfo = info
        center.playbackState = state.isPlaying ? .playing : .paused
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipBackwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.preferredIntervals = [10]

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.state.isReady, !self.state.isPlaying else { return }
                self.togglePlay()
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.state.isReady, self.state.isPlaying else { return }
                self.togglePlay()
            }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlay() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor [weak self] in self?.seek(to: position) }
            return .success
        }
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.seek(to: (self?.state.time ?? 0) + 10) }
            return .success
        }
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.seek(to: max((self?.state.time ?? 0) - 10, 0)) }
            return .success
        }
    }

    private func handleTick(_ time: CMTime) {
        guard state.isReady else { return }
        let seconds = time.seconds
        if seconds.isFinite, seconds >= 0 {
            state.time = seconds
        }
        updateDuration()

        switch player.timeControlStatus {
        case .playing:
            state.isPlaying = true
            if !pausedByUser {
                state.isBuffering = false
                state.phase = .playing
            }
        case .waitingToPlayAtSpecifiedRate:
            state.isPlaying = !pausedByUser
            state.isBuffering = !pausedByUser
        case .paused:
            state.isPlaying = false
            state.isBuffering = false
            if pausedByUser {
                state.phase = .paused
            }
        @unknown default:
            break
        }
    }

    private func updateDuration() {
        guard let item = player.currentItem else { return }
        let seconds = item.duration.seconds
        if seconds.isFinite, seconds > 0 {
            state.duration = seconds
        }
    }
}

extension PlayerCoordinator: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in self?.isPiPActive = true }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in self?.isPiPActive = false }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isPiPActive = false
            self?.state.error = "画中画启动失败"
        }
    }
}
