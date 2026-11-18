import Foundation
import Observation

enum InteractionOutcome: Sendable, Equatable {
    case ok
    case needsLogin
    case unauthorized
    case failed(String)
}

/// 当前播放条目的详情与互动状态。Feed / 详情面板共用同一份，避免两处点赞不同步。
@MainActor
@Observable
final class FeedInteractionModel {
    private let social: VideoSocialRepository
    private let library: LocalLibrary
    private var detailTask: Task<Void, Never>?

    private(set) var videoID: Int
    private(set) var ep: Int
    private(set) var card: VideoCard?
    private(set) var detail: VideoDetail?
    private(set) var isLoadingDetail = false
    private(set) var didLoadDetail = false
    var error: String?

    var liked = false
    var collected = false
    var following = false
    var likeCount = 0
    var collectCount = 0
    var commentCount = 0
    var authorID: Int?
    var authorName: String = ""
    var likedEp: Int?

    init(card: VideoCard?, ep: Int, social: VideoSocialRepository, library: LocalLibrary) {
        self.social = social
        self.library = library
        self.card = card
        self.videoID = card?.id ?? 0
        self.ep = max(ep, 1)
        applyCard(card)
    }

    var title: String { detail?.displayTitle ?? card?.displayTitle ?? "视频" }
    var description: String {
        let value = detail?.description ?? card?.description ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var tags: [String] { detail?.tags ?? card?.tags ?? [] }
    var episodeTotal: Int { detail?.episodeTotal ?? card?.episodeTotal ?? 1 }

    func configure(card: VideoCard, ep: Int) {
        let sameVideo = videoID == card.id
        self.card = card
        self.videoID = card.id
        self.ep = max(ep, 1)

        if !sameVideo {
            detailTask?.cancel()
            detail = nil
            didLoadDetail = false
            isLoadingDetail = false
            error = nil
            applyCard(card)
            detailTask = Task { @MainActor [weak self] in
                await self?.loadDetail()
            }
        } else if !didLoadDetail, !isLoadingDetail {
            detailTask = Task { @MainActor [weak self] in
                await self?.loadDetail()
            }
        }
    }

    func loadDetail(force: Bool = false) async {
        guard videoID > 0, !isLoadingDetail else { return }
        if didLoadDetail, !force { return }
        isLoadingDetail = true
        defer { isLoadingDetail = false }

        do {
            let value = try await social.detail(id: videoID)
            guard value.id == videoID else { return }
            detail = value
            didLoadDetail = true
            error = nil
            apply(value)
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - 互动

    func toggleLike() async -> InteractionOutcome {
        guard videoID > 0 else { return .failed("视频不存在") }
        let next = !liked
        let previousLiked = liked
        let previousCount = likeCount

        liked = next
        likeCount = max(0, likeCount + (next ? 1 : -1))

        do {
            try await social.like(id: videoID, ep: ep, on: next)
            library.setLiked(videoID, next)
            return .ok
        } catch let error as APIError {
            liked = previousLiked
            likeCount = previousCount
            if case .unauthorized = error { return .unauthorized }
            return .failed(error.localizedDescription)
        } catch {
            liked = previousLiked
            likeCount = previousCount
            return .failed(error.localizedDescription)
        }
    }

    func toggleCollect() async -> InteractionOutcome {
        guard videoID > 0 else { return .failed("视频不存在") }
        let next = !collected
        let previous = collected
        let previousCount = collectCount

        collected = next
        collectCount = max(0, collectCount + (next ? 1 : -1))

        do {
            try await social.collect(id: videoID, on: next)
            library.setFavorite(videoID, next)
            return .ok
        } catch let error as APIError {
            collected = previous
            collectCount = previousCount
            if case .unauthorized = error { return .unauthorized }
            return .failed(error.localizedDescription)
        } catch {
            collected = previous
            collectCount = previousCount
            return .failed(error.localizedDescription)
        }
    }

    func toggleFollow() async -> InteractionOutcome {
        guard let authorID else { return .failed("作者信息缺失") }
        let next = !following
        let previous = following
        following = next

        do {
            try await social.follow(uid: authorID, on: next)
            library.setFollowing(authorID, next)
            return .ok
        } catch let error as APIError {
            following = previous
            if case .unauthorized = error { return .unauthorized }
            return .failed(error.localizedDescription)
        } catch {
            following = previous
            return .failed(error.localizedDescription)
        }
    }

    func noteCommentSent() {
        commentCount += 1
    }

    // MARK: - 应用详情

    private func applyCard(_ card: VideoCard?) {
        guard let card else {
            likeCount = 0
            collectCount = 0
            commentCount = 0
            authorID = nil
            authorName = ""
            return
        }
        liked = library.isLiked(card.id)
        collected = library.isFavorite(card.id)
        likeCount = max(card.likeCount ?? 0, 0)
        collectCount = max(card.collectCount ?? 0, 0)
        commentCount = max(card.commentCount ?? 0, 0)
        authorID = card.author?.id
        authorName = card.authorName
        following = authorID.map(library.isFollowing) ?? false
    }

    private func apply(_ detail: VideoDetail) {
        if let counts = detail.counts {
            if let like = counts.like { likeCount = max(like, 0) }
            if let collect = counts.collect { collectCount = max(collect, 0) }
            if let comment = counts.comment { commentCount = max(comment, 0) }
        }
        if let interaction = detail.interaction {
            // 匿名详情的 interaction 一定是 false；只有 true 才覆盖本地状态，
            // 避免每次进详情把本地点赞/收藏清掉。取消操作由 toggle 本地写入。
            if interaction.liked == true {
                liked = true
                library.setLiked(videoID, true)
            } else if !library.isLiked(videoID) {
                liked = false
            }
            if interaction.collected == true {
                collected = true
                library.setFavorite(videoID, true)
            } else if !library.isFavorite(videoID) {
                collected = false
            }
            likedEp = interaction.likedEp
        }
        if let author = detail.author {
            if let id = author.id { authorID = id }
            if let name = author.name, !name.isEmpty { authorName = name }
            if author.isFollowing == true {
                following = true
                if let authorID { library.setFollowing(authorID, true) }
            } else if let authorID {
                following = library.isFollowing(authorID)
            }
        }
    }
}
