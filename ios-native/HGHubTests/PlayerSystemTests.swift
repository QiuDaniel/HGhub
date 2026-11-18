import MediaPlayer
import Testing
@testable import HGHub

private struct SystemPlayerRepository: VideoRepository {
    func feed(page: Int, size: Int) async throws -> Paged<VideoCard> {
        Paged(items: [], pagination: Pagination(page: page, pages: 1, size: size, total: 0))
    }

    func playback(id: Int, ep: Int) async throws -> PlayInfo {
        PlayInfo(
            id: id,
            epNum: ep,
            title: "第\(ep)集",
            duration: 0,
            videoURL: "https://example.com/\(id)/\(ep).m3u8",
            videoURLHEVC: nil,
            cdn: nil
        )
    }
}

@MainActor
struct PlayerSystemTests {
    @Test
    func configuresLockScreenMetadataAndRemoteCommands() {
        let coordinator = PlayerCoordinator(videos: SystemPlayerRepository())
        coordinator.updateMetadata(title: "测试标题", subtitle: "第 1 集 · 作者")

        let center = MPRemoteCommandCenter.shared()
        #expect(center.playCommand.isEnabled)
        #expect(center.pauseCommand.isEnabled)
        #expect(center.togglePlayPauseCommand.isEnabled)
        #expect(center.changePlaybackPositionCommand.isEnabled)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        #expect(info?[MPMediaItemPropertyTitle] as? String == "测试标题")
        #expect(info?[MPMediaItemPropertyArtist] as? String == "第 1 集 · 作者")

        coordinator.stop()
    }
}
