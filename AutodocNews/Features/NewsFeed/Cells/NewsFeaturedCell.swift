import UIKit

final class NewsFeaturedCell: UICollectionViewCell, NewsCardDisplaying {
    private typealias Featured = Constants.Feed.Layout.Featured

    private let imageView = RemoteImageView(frame: .zero)
    private let scrimView = GradientView()
    private let categoryBadge = BadgeLabel(style: .overlay)
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private lazy var binder: any NewsCardContentBinding = NewsCardContentBinder(
        cell: self,
        imageView: imageView,
        categoryBadge: categoryBadge,
        titleLabel: titleLabel,
        dateLabel: dateLabel
    )

    var transitionSourceView: UIView { imageView }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureLabels()
        configureLayout()
        binder.configureAccessibility()
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
        CardShape.applyCorners(to: imageView)
        CardShape.applyCorners(to: scrimView, maskedCorners: CardShape.bottomCorners)
        hoverStyle = CardShape.hoverStyle()
    }

    private func configureLabels() {
        configureTitleLabel()
        configureDateLabel()
        for label in [titleLabel, dateLabel] {
            label.adjustsFontForContentSizeCategory = true
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
    }

    private func configureTitleLabel() {
        titleLabel.font = Typography.featuredTitle
        titleLabel.textColor = Palette.overlayText
        titleLabel.numberOfLines = Featured.titleMaxLines
        titleLabel.lineBreakMode = .byTruncatingTail
    }

    private func configureDateLabel() {
        dateLabel.font = Typography.caption
        dateLabel.textColor = Palette.overlayText.withAlphaComponent(Featured.dateTextAlpha)
    }

    private func configureLayout() {
        contentView.addSubviews(imageView, scrimView, categoryBadge, titleLabel, dateLabel)
        imageView.pinEdges(to: contentView)
        layoutScrimView()
        layoutDateLabel()
        layoutTitleLabel()
        layoutCategoryBadge()
        imageView.placeFailureIcon(above: categoryBadge.topAnchor)
    }

    private func layoutScrimView() {
        NSLayoutConstraint.activate([
            scrimView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrimView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            scrimView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: Featured.scrimHeightRatio)
        ])
    }

    private func layoutDateLabel() {
        let insets = Featured.textInsets
        NSLayoutConstraint.activate([
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: insets.leading),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -insets.trailing),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -insets.bottom)
        ])
    }

    private func layoutTitleLabel() {
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: dateLabel.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: dateLabel.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: dateLabel.topAnchor, constant: -Featured.interitemSpacing)
        ])
    }

    private func layoutCategoryBadge() {
        NSLayoutConstraint.activate([
            categoryBadge.leadingAnchor.constraint(equalTo: dateLabel.leadingAnchor),
            categoryBadge.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.trailingAnchor),
            categoryBadge.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -Featured.interitemSpacing)
        ])
    }
}
