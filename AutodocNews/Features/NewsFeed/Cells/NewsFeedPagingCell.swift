import UIKit

final class NewsFeedPagingCell: UICollectionViewCell {
    enum Content: Equatable {
        case loading
        case failed(message: String)
    }

    private let spinner = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()
    private let retryButton = UIButton(configuration: .tinted())
    private let stackView = UIStackView()
    private var onRetry: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSpinner()
        configureMessageLabel()
        configureRetryButton()
        configureStackView()
        layoutStackView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onRetry = nil
    }

    func configure(with content: Content, onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
        switch content {
        case .loading:
            showLoading()
        case .failed(let message):
            showFailure(message: message)
        }
    }

    private func showLoading() {
        spinner.startAnimating()
        messageLabel.isHidden = true
        retryButton.isHidden = true
    }

    private func showFailure(message: String) {
        spinner.stopAnimating()
        messageLabel.text = message
        messageLabel.isHidden = false
        retryButton.isHidden = false
    }

    private func configureSpinner() {
        spinner.hidesWhenStopped = true
        spinner.accessibilityLabel = Constants.Feed.Text.pagingLoadingAccessibilityLabel
    }

    private func configureMessageLabel() {
        messageLabel.font = Typography.caption
        messageLabel.textColor = Palette.secondaryText
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
    }

    private func configureRetryButton() {
        retryButton.configuration?.title = Constants.Feed.Text.retry
        retryButton.configuration?.cornerStyle = .capsule
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .primaryActionTriggered)
    }

    private func configureStackView() {
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = Constants.Feed.Layout.PagingFooter.stackSpacing
        [spinner, messageLabel, retryButton].forEach(stackView.addArrangedSubview)
    }

    private func layoutStackView() {
        contentView.addSubviews(stackView)
        stackView.pinEdges(to: contentView, insets: Constants.Feed.Layout.PagingFooter.contentInsets)
    }
}
