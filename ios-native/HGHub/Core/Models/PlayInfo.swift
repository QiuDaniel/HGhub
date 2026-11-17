import Foundation

struct CDNInfo: Sendable, Hashable {
    let authKey: String?
    let authValue: String?
}

/// 播放信息。上游 playback 的 `streams.main / hevc / preview` 由 `VideoRepository` 归一化到这里。
struct PlayInfo: Sendable, Hashable {
    let id: Int
    let epNum: Int
    let title: String
    let duration: Double
    let videoURL: String
    let videoURLHEVC: String?
    let cdn: CDNInfo?
}
