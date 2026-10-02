import UIKit

final class NewsCardCell: UICollectionViewCell, NewsCardDisplaying {
    private typealias Card = Constants.Feed.Layout.Card

    private let imageView = RemoteImageView(frame: .zero)
    private let categoryBadge = BadgeLabel(style: .tinted)
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private lazy var binder: any NewsCardContentBinding = NewsCardContentBinder(
        cell: self,
        imageView: imageView,
        categoryBadge: categoryBadge,
        titleLabel: titleLabel,
        dateLabel: dateLabel
    )
    private let textArea = NewsCardTextArea()

    var transitionSourceView: UIView { imageView }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureLabels()
        configureLayout()
        binder.configureAccessibility()
        observeContentSizeCategory()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        binder.cancelImageLoading()
    }

    override var isHighlighted: Bool {
        didSet { CardHighlight.apply(isHighlighted, to: contentView) }
    }

    func configure(with content: NewsCardContent, imageLoader: any ImageLoading) {
        binder.bind(content, imageLoader: imageLoader)
    }

    func resetContent() {
        binder.reset()
    }

    private func configureAppearance() {
        CardShape.applyCardBackground(to: contentView)
        imageView.placeholderColor = Palette.imagePlaceholder
        CardShape.applyCorners(to: imageView, maskedCorners: CardShape.topCorners)
        hoverStyle = CardShape.hoverStyle()
    }

    private func configureLabels() {
        configureTitleLabel()
        configureDateLabel()
        for label in [titleLabel, dateLabel] {
            label.adjustsFontForContentSizeCategory = true
            label.backgroundColor = Palette.cardBackground
        }
    }

    private func configureTitleLabel() {
        titleLabel.font = Typography.cardTitle
        titleLabel.textColor = Palette.primaryText
        titleLabel.numberOfLines = Card.titleMaxLines
        titleLabel.lineBreakMode = .byTruncatingTail
    }

    private func configureDateLabel() {
        dateLabel.font = Typography.caption
        dateLabel.textColor = Palette.secondaryText
    }

    private func configureLayout() {
        contentView.addSubviews(imageView, categoryBadge, titleLabel, dateLabel)
        textArea.install(in: contentView, below: imageView)
        layoutCategoryBadge()
        layoutTitleLabel()
        layoutDateLabel()
    }

    private func layoutCategoryBadge() {
        NSLayoutConstraint.activate([
            categoryBadge.topAnchor.constraint(equalTo: textArea.guide.topAnchor, constant: Card.textInsets.top),
            categoryBadge.leadingAnchor.constraint(equalTo: textArea.guide.leadingAnchor),
            categoryBadge.trailingAnchor.constraint(lessThanOrEqualTo: textArea.guide.trailingAnchor)
        ])
    }

    private func layoutTitleLabel() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: categoryBadge.bottomAnchor, constant: Card.badgeToTitleSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: textArea.guide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: textArea.guide.trailingAnchor)
        ])
    }

    private func layoutDateLabel() {
        NSLayoutConstraint.activate([
            dateLabel.leadingAnchor.constraint(equalTo: textArea.guide.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: textArea.guide.trailingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: textArea.guide.bottomAnchor, constant: -Card.textInsets.bottom)
        ])
    }

    private func observeContentSizeCategory() {
        textArea.updateHeight(for: traitCollection)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _: UITraitCollection) in
            self.textArea.updateHeight(for: self.traitCollection)
        }
    }
}
