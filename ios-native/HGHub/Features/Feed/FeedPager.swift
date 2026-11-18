import Nuke
import SwiftUI
import UIKit

/// 竖滑分页器：只负责当前第几条、封面和手势仲裁。
/// 视频画面由 `FeedScreen` 叠在上方的单 `AVPlayerLayer` 负责。
struct FeedPager: UIViewRepresentable {
    enum Edge {
        case brightness
        case volume
    }

    let cards: [VideoCard]
    @Binding var index: Int

    var onTap: () -> Void = {}
    var onDoubleTap: () -> Void = {}
    var onLongPressChanged: (Bool) -> Void = { _ in }
    var onScrubBegan: () -> Void = {}
    var onScrubChanged: (Double) -> Void = { _ in }
    var onScrubEnded: (Double) -> Void = { _ in }
    var onEdgeBegan: (Edge) -> Void = { _ in }
    var onEdgeChanged: (Double) -> Void = { _ in }
    var onEdgeEnded: () -> Void = {}
    var onNearEnd: (Int) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isPagingEnabled = true
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.allowsSelection = false
        collectionView.register(FeedCoverCell.self, forCellWithReuseIdentifier: FeedCoverCell.reuseID)
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator

        context.coordinator.collectionView = collectionView
        context.coordinator.installGestures()
        context.coordinator.scroll(to: index, animated: false)

        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(cards: cards, index: index)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate {
        var parent: FeedPager
        weak var collectionView: UICollectionView?

        private var cardIDs: [Int] = []
        private var currentIndex = 0
        private var isProgrammaticScroll = false
        private var scrollAttempts = 0

        private var scrubPan: UIPanGestureRecognizer?
        private var scrubMode: PanMode = .none
        private var edgeKind: Edge = .brightness

        private enum PanMode {
            case none
            case scrub
            case edge
        }

        init(parent: FeedPager) {
            self.parent = parent
            self.currentIndex = max(0, parent.index)
            self.cardIDs = parent.cards.map(\.id)
            super.init()
        }

        func sync(cards: [VideoCard], index: Int) {
            let ids = cards.map(\.id)
            if ids != cardIDs {
                cardIDs = ids
                collectionView?.reloadData()
                currentIndex = max(0, min(index, max(cards.count - 1, 0)))
                scroll(to: currentIndex, animated: false)
                return
            }
            guard index != currentIndex else { return }
            currentIndex = max(0, min(index, max(cards.count - 1, 0)))
            scroll(to: currentIndex, animated: false)
        }

        func scroll(to index: Int, animated: Bool) {
            guard let collectionView, cardIDs.indices.contains(index) else { return }
            let height = collectionView.bounds.height
            guard height > 0 else {
                guard scrollAttempts < 12 else { return }
                scrollAttempts += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                    self?.scroll(to: index, animated: false)
                }
                return
            }
            scrollAttempts = 0
            isProgrammaticScroll = true
            currentIndex = index
            collectionView.setContentOffset(
                CGPoint(x: 0, y: CGFloat(index) * height),
                animated: animated
            )
            DispatchQueue.main.async { [weak self] in
                self?.isProgrammaticScroll = false
            }
        }

        // MARK: Data source

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            cardIDs.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: FeedCoverCell.reuseID,
                for: indexPath
            ) as! FeedCoverCell
            if parent.cards.indices.contains(indexPath.item) {
                cell.configure(card: parent.cards[indexPath.item])
            }
            return cell
        }

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            collectionView.bounds.size
        }

        func collectionView(
            _ collectionView: UICollectionView,
            willDisplay cell: UICollectionViewCell,
            forItemAt indexPath: IndexPath
        ) {
            if indexPath.item >= cardIDs.count - 3 {
                parent.onNearEnd(indexPath.item)
            }
        }

        // MARK: Scroll

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isProgrammaticScroll else { return }
            let height = scrollView.bounds.height
            guard height > 0, !cardIDs.isEmpty else { return }
            let raw = scrollView.contentOffset.y / height
            let next = max(0, min(Int(raw.rounded()), cardIDs.count - 1))
            guard next != currentIndex else { return }
            currentIndex = next
            parent.index = next
            if next >= cardIDs.count - 3 {
                parent.onNearEnd(next)
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            snapToNearestPage(scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            guard !decelerate else { return }
            snapToNearestPage(scrollView)
        }

        private func snapToNearestPage(_ scrollView: UIScrollView) {
            let height = scrollView.bounds.height
            guard height > 0 else { return }
            let page = Int((scrollView.contentOffset.y / height).rounded())
            scroll(to: max(0, min(page, cardIDs.count - 1)), animated: true)
        }

        // MARK: Gestures

        func installGestures() {
            guard let collectionView else { return }

            let single = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
            single.cancelsTouchesInView = false

            let double = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
            double.numberOfTapsRequired = 2
            double.cancelsTouchesInView = false
            single.require(toFail: double)

            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.4
            longPress.allowableMovement = 12
            longPress.cancelsTouchesInView = false

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            pan.cancelsTouchesInView = false
            pan.maximumNumberOfTouches = 1
            scrubPan = pan

            collectionView.addGestureRecognizer(single)
            collectionView.addGestureRecognizer(double)
            collectionView.addGestureRecognizer(longPress)
            collectionView.addGestureRecognizer(pan)

            // 先让专用 pan 决定方向：横向/边缘纵向吃掉，中心纵向失败后交给 pager。
            collectionView.panGestureRecognizer.require(toFail: pan)
        }

        @objc private func handleSingleTap() {
            parent.onTap()
        }

        @objc private func handleDoubleTap() {
            parent.onDoubleTap()
        }

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            switch gesture.state {
            case .began:
                parent.onLongPressChanged(true)
            case .ended, .cancelled, .failed:
                parent.onLongPressChanged(false)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === scrubPan,
                  let collectionView,
                  let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }

            let velocity = pan.velocity(in: collectionView)
            guard abs(velocity.x) > 4 || abs(velocity.y) > 4 else { return false }
            let location = pan.location(in: collectionView)
            let width = max(collectionView.bounds.width, 1)

            if abs(velocity.x) > abs(velocity.y) * 1.15 {
                scrubMode = .scrub
                return true
            }

            if (location.x < width * 0.2 || location.x > width * 0.8),
               abs(velocity.y) > abs(velocity.x) {
                scrubMode = .edge
                edgeKind = location.x < width * 0.2 ? .brightness : .volume
                return true
            }

            scrubMode = .none
            return false
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let collectionView else { return }
            let height = max(collectionView.bounds.height, 1)
            let width = max(collectionView.bounds.width, 1)
            let translation = gesture.translation(in: collectionView)

            switch gesture.state {
            case .began:
                if scrubMode == .scrub {
                    parent.onScrubBegan()
                } else if scrubMode == .edge {
                    parent.onEdgeBegan(edgeKind)
                }
            case .changed:
                if scrubMode == .scrub {
                    parent.onScrubChanged(Double(translation.x / width))
                } else if scrubMode == .edge {
                    parent.onEdgeChanged(Double(-translation.y / height))
                }
            case .ended, .cancelled, .failed:
                if scrubMode == .scrub {
                    parent.onScrubEnded(Double(translation.x / width))
                } else if scrubMode == .edge {
                    parent.onEdgeEnded()
                }
                scrubMode = .none
            default:
                break
            }
        }
    }
}

// MARK: - Cover cell

final class FeedCoverCell: UICollectionViewCell {
    static let reuseID = "FeedCoverCell"

    private let imageView = UIImageView()
    private let gradient = CAGradientLayer()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var task: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .black
        contentView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.55).cgColor,
        ]
        gradient.locations = [0.45, 1]
        contentView.layer.addSublayer(gradient)

        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(spinner)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = contentView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        task?.cancel()
        task = nil
        imageView.image = nil
        spinner.stopAnimating()
    }

    func configure(card: VideoCard) {
        task?.cancel()
        imageView.image = nil

        guard let cover = card.cover,
              let url = URL(string: cover) else {
            spinner.stopAnimating()
            return
        }

        spinner.startAnimating()
        task = Task { @MainActor [weak self] in
            do {
                let image = try await ImagePipeline.shared.image(for: url)
                guard !Task.isCancelled else { return }
                self?.imageView.image = image
                self?.spinner.stopAnimating()
            } catch {
                guard !Task.isCancelled else { return }
                self?.spinner.stopAnimating()
            }
        }
    }
}
