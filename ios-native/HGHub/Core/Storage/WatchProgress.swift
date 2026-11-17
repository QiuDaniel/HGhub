import Defaults
import Foundation

/// 单条观看记录。`t` 是秒，`dur` 是总时长（用于判断是否看完）。
struct WatchProgress: Codable, Defaults.Serializable, Sendable, Hashable, Identifiable {
    let id: Int
    var ep: Int
    var t: Double
    var dur: Double
    var at: Date
}
