import Foundation

/// 全屏播放的上下文。从首页/搜索/分类/我的都能构造，交给根视图的 fullScreenCover。
struct FeedContext: Identifiable, Hashable, Sendable {
    let id: UUID
    var videoIDs: [Int]
    var index: Int
    var title: String
    var source: String
    var startEp: Int?
    var startTime: Double?

    init(
        videoIDs: [Int],
        index: Int,
        title: String,
        source: String = "home",
        startEp: Int? = nil,
        startTime: Double? = nil
    ) {
        self.id = UUID()
        self.videoIDs = videoIDs
        self.index = index
        self.title = title
        self.source = source
        self.startEp = startEp
        self.startTime = startTime
    }
}
