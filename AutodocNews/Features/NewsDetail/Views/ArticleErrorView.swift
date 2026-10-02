import UIKit

@MainActor
final class ArticleErrorView: UIView {
    private static let stackInsets = NSDirectionalEdgeInsets(top: Spacing.xl, leading: 0, bottom: Spacing.xl, trailing: 0)

    var onRetry: (() -> Void)?

    private let iconView = UIImageView()
    private let messageLabel = UILabel()
    private lazy var retryButton = UIButton(
        configuration: Self.makeRetryButtonConfiguration(),
        primaryAction: UIAction { [weak self] _ in self?.onRetry?() }
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureIcon()
        configureMessageLabel()
        layoutStack()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(message: String) {
        messageLabel.text = message
    }

    private func configureIcon() {
        let symbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)
        iconView.image = UIImage(systemName: Constants.Detail.Symbol.error, withConfiguration: symbolConfiguration)
        iconView.tintColor = Palette.secondaryText
        iconView.contentMode = .center
        iconView.isAccessibilityElement = false
    }

    private func configureMessageLabel() {
        messageLabel.font = Typography.body
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = Palette.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
    }

    private func layoutStack() {
        let stackView = UIStackView(arrangedSubviews: [iconView, messageLabel, retryButton])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = Spacing.m
        stackView.setCustomSpacing(Spacing.l, after: messageLabel)
        addSubviews(stackView)
        stackView.pinEdges(to: self, insets: Self.stackInsets)
    }

    private static func makeRetryButtonConfiguration() -> UIButton.Configuration {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = Constants.Detail.Text.retry
        configuration.image = UIImage(systemName: Constants.Detail.Symbol.retry)
        configuration.imagePadding = Spacing.s
        configuration.cornerStyle = .capsule
        configuration.baseForegroundColor = Palette.accent
        configuration.baseBackgroundColor = Palette.accent
        return configuration
    }
}
