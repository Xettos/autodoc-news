import UIKit

final class NewsFeedMessageBanner: UIView {
    private typealias Animation = Constants.Feed.Animation

    private let messageLabel = UILabel()
    private var hideTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureLabel()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        setVisible(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show(_ message: String) {
        messageLabel.text = message
        accessibilityLabel = message
        UIAccessibility.post(notification: .announcement, argument: message)
        animateVisibility(to: true)
        scheduleHide()
    }

    func place(in container: UIView) {
        container.addSubviews(self)
        pinToBottom(of: container.safeAreaLayoutGuide)
    }

    private func pinToBottom(of guide: UILayoutGuide) {
        let banner = Constants.Feed.Layout.Banner.self
        let preferredWidth = widthAnchor.constraint(equalToConstant: banner.maximumWidth)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: banner.edgeInset),
            bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -banner.edgeInset),
            preferredWidth
        ])
    }

    private func configureAppearance() {
        backgroundColor = .label
        layer.cornerRadius = CornerRadius.card
        layer.cornerCurve = .continuous
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    private func configureLabel() {
        messageLabel.font = Typography.caption
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .systemBackground
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        addSubviews(messageLabel)
        messageLabel.pinEdges(to: self, insets: Constants.Feed.Layout.Banner.contentInsets)
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Animation.bannerVisibleDuration)
            guard !Task.isCancelled else { return }
            self?.animateVisibility(to: false)
        }
    }

    private func animateVisibility(to isVisible: Bool) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            setVisible(isVisible)
            return
        }
        UIView.animate(
            withDuration: Animation.bannerTransitionDuration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut]
        ) {
            self.setVisible(isVisible)
        }
    }

    private func setVisible(_ isVisible: Bool) {
        alpha = isVisible ? 1 : 0
        transform = isVisible ? .identity : CGAffineTransform(translationX: 0, y: Animation.bannerHiddenOffset)
        isUserInteractionEnabled = isVisible
    }

    @objc private func handleTap() {
        hideTask?.cancel()
        animateVisibility(to: false)
    }
}
