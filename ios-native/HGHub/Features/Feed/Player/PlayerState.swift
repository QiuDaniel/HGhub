import Foundation
import Observation

@MainActor
@Observable
final class PlayerState {
    enum Phase: Sendable {
        case idle
        case loading
        case playing
        case paused
        case failed
    }

    var phase: Phase = .idle
    var time: Double = 0
    var duration: Double = 0
    var isPlaying = false
    var isBuffering = false
    var isReady = false
    var isMuted = false
    var volume: Float = 1
    var rate: Float = 1
    var error: String?
    var ended = false
    var currentID: Int?
    var currentEp: Int?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(time / duration, 0), 1)
    }

    var timeText: String {
        Self.clock(time)
    }

    var durationText: String {
        Self.clock(duration)
    }

    func resetForLoad(id: Int, ep: Int) {
        phase = .loading
        time = 0
        duration = 0
        isPlaying = false
        isBuffering = true
        isReady = false
        error = nil
        ended = false
        currentID = id
        currentEp = ep
    }

    func clear() {
        phase = .idle
        time = 0
        duration = 0
        isPlaying = false
        isBuffering = false
        isReady = false
        error = nil
        ended = false
        currentID = nil
        currentEp = nil
    }

    static func clock(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "00:00" }
        let total = Int(value.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
