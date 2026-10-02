import UIKit

@MainActor
protocol NewsDetailHeaderDisplaying: UIView {
    var heroView: UIView? { get }

    func configure(with data: NewsDetailHeaderViewData)
    func alignContent(to columnGuide: UILayoutGuide)
    func titleMaxY(in view: UIView) -> CGFloat
}

@MainActor
final class NewsDetailHeaderView: UIView {
    private typealias Layout = Constants.Detail.Layout

    private let imageLoader: any ImageLoading
    private let heroRequestPolicy: any HeroImageRequestDeciding

    private let heroImageView = RemoteImageView(frame: .zero)
    private let badgeLabel = BadgeLabel(style: .tinted)
    private let dateLabel = UILabel()
    private let metaStackView = UIStackView()
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let textStackView = UIStackView()

    private var heroImageURL: URL?
    private var heroRequest: ImageRequest?
    private var heroTopConstraint: NSLayoutConstraint?
    private var textBelowHeroConstraint: NSLayoutConstraint?
    private var textAtTopConstraint: NSLayoutConstraint?
    private var compactHeroConstraints: [NSLayoutConstraint] = []
    private var regularHeroConstraints: [NSLayoutConstraint] = []
    private var isContentAligned = false

    init(imageLoader: any ImageLoading, heroRequestPolicy: any HeroImageRequestDeciding) {
        self.imageLoader = imageLoader
        self.heroRequestPolicy = heroRequestPolicy
        super.init(frame: .zero)
        styleLabels()
        configureMetaStack()
        configureTextStack()
        configureHero()
        observeContentSizeCategory()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        requestHeroImageIfNeeded()
    }

    private func configureMeta(with data: NewsDetailHeaderViewData) {
        badgeLabel.text = data.category
        badgeLabel.isHidden = data.category == nil
        dateLabel.text = data.publishedDateText
        dateLabel.isHidden = data.publishedDateText == nil
        dateLabel.accessibilityLabel = data.publishedDateText.map(Self.publishedAccessibilityLabel(for:))
        metaStackView.isHidden = badgeLabel.isHidden && dateLabel.isHidden
    }

    private func configureTexts(with data: NewsDetailHeaderViewData) {
        titleLabel.text = data.title
        summaryLabel.text = data.summary
        summaryLabel.isHidden = data.summary == nil
    }

    private func configureHeroImage(url: URL?) {
        if url != heroImageURL {
            resetHeroImage()
        }
        heroImageURL = url
        heroImageView.isHidden = url == nil
        showCachedHeroPreview()
        updateTextTopConstraint()
        setNeedsLayout()
    }

    private static func publishedAccessibilityLabel(for dateText: String) -> String {
        String(format: Constants.Detail.Text.publishedAccessibilityFormat, dateText)
    }

    private func styleLabels() {
        style(dateLabel, font: Typography.caption, color: Palette.secondaryText)
        style(titleLabel, font: Typography.detailTitle, color: Palette.primaryText)
        style(summaryLabel, font: Typography.body, color: Palette.secondaryText)
        titleLabel.accessibilityTraits = .header
        badgeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func style(_ label: UILabel, font: UIFont, color: UIColor) {
        label.font = font
        label.textColor = color
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
    }

    private func configureMetaStack() {
        metaStackView.addArrangedSubview(badgeLabel)
        metaStackView.addArrangedSubview(dateLabel)
        metaStackView.spacing = Spacing.s
        updateMetaAxis()
    }

    private func configureTextStack() {
        [metaStackView, titleLabel, summaryLabel].forEach(textStackView.addArrangedSubview)
        textStackView.axis = .vertical
        textStackView.alignment = .fill
        textStackView.spacing = Spacing.m
        addSubviews(textStackView)
    }

    private func configureHero() {
        heroImageView.placeholderColor = Palette.imagePlaceholder
        heroImageView.layer.cornerCurve = .continuous
        heroImageView.isHidden = true
        addSubviews(heroImageView)
    }

    private func alignTextStack(to columnGuide: UILayoutGuide) {
        textBelowHeroConstraint = textStackView.topAnchor.constraint(equalTo: heroImageView.bottomAnchor, constant: Spacing.xl)
        textAtTopConstraint = textStackView.topAnchor.constraint(equalTo: topAnchor, constant: Spacing.l)
        NSLayoutConstraint.activate([
            textStackView.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            textStackView.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
            textStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func updateTextTopConstraint() {
        let hasHero = heroImageURL != nil
        textAtTopConstraint?.isActive = !hasHero
        textBelowHeroConstraint?.isActive = hasHero
    }

    private func installHeroConstraints(columnGuide: UILayoutGuide) {
        activateHeroSizeConstraints()
        compactHeroConstraints = makeCompactHeroConstraints()
        regularHeroConstraints = makeRegularHeroConstraints(columnGuide: columnGuide)
        updateHeroLayout()
    }

    private func activateHeroSizeConstraints() {
        let topConstraint = heroImageView.topAnchor.constraint(equalTo: topAnchor)
        heroTopConstraint = topConstraint
        let aspectConstraint = heroImageView.heightAnchor.constraint(
            equalTo: heroImageView.widthAnchor,
            multiplier: Layout.heroAspectRatio
        )
        aspectConstraint.priority = Layout.heroAspectPriority
        NSLayoutConstraint.activate([
            topConstraint,
            aspectConstraint,
            heroImageView.heightAnchor.constraint(lessThanOrEqualToConstant: Layout.maxHeroHeight)
        ])
    }

    private func makeCompactHeroConstraints() -> [NSLayoutConstraint] {
        [
            heroImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            heroImageView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ]
    }

    private func makeRegularHeroConstraints(columnGuide: UILayoutGuide) -> [NSLayoutConstraint] {
        let preferredColumnWidth = heroImageView.widthAnchor.constraint(equalTo: columnGuide.widthAnchor)
        preferredColumnWidth.priority = .defaultHigh
        return [
            heroImageView.centerXAnchor.constraint(equalTo: columnGuide.centerXAnchor),
            heroImageView.widthAnchor.constraint(lessThanOrEqualTo: columnGuide.widthAnchor),
            preferredColumnWidth
        ]
    }

    private func updateHeroLayout() {
        let isRegular = traitCollection.horizontalSizeClass == .regular
        NSLayoutConstraint.deactivate(isRegular ? compactHeroConstraints : regularHeroConstraints)
        NSLayoutConstraint.activate(isRegular ? regularHeroConstraints : compactHeroConstraints)
        heroTopConstraint?.constant = isRegular ? Spacing.l : 0
        heroImageView.layer.cornerRadius = isRegular ? CornerRadius.card : 0
    }

    private func updateMetaAxis() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        metaStackView.axis = isAccessibilitySize ? .vertical : .horizontal
        metaStackView.alignment = isAccessibilitySize ? .leading : .center
    }

    private func observeContentSizeCategory() {
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _: UITraitCollection) in
            self.updateMetaAxis()
        }
    }

    private func observeHorizontalSizeClass() {
        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: Self, _: UITraitCollection) in
            self.updateHeroLayout()
        }
    }

    private func requestHeroImageIfNeeded() {
        guard let url = heroImageURL, !heroImageView.bounds.isEmpty else { return }
        let request = ImageRequest(url: url, targetSize: heroImageView.bounds.size, scale: traitCollection.displayScale)
        let shouldReplace = heroRequestPolicy.shouldReplace(
            current: heroRequest,
            displayedPixelSize: displayedHeroPixelSize,
            with: request
        )
        guard shouldReplace else { return }
        heroRequest = request
        heroImageView.setImage(request, using: imageLoader)
        showCachedHeroPreview()
    }

    private var displayedHeroPixelSize: ImageRequest.PixelSize? {
        guard let cgImage = heroImageView.image?.cgImage else { return nil }
        return ImageRequest.PixelSize(width: cgImage.width, height: cgImage.height)
    }

    private func showCachedHeroPreview() {
        guard heroImageView.image == nil, let url = heroImageURL else { return }
        heroImageView.image = imageLoader.cachedImage(forURL: url)
    }

    private func resetHeroImage() {
        heroRequest = nil
        heroImageView.cancelLoading()
    }
}

extension NewsDetailHeaderView: NewsDetailHeaderDisplaying {
    var heroView: UIView? {
        heroImageURL == nil ? nil : heroImageView
    }

    func configure(with data: NewsDetailHeaderViewData) {
        configureMeta(with: data)
        configureTexts(with: data)
        configureHeroImage(url: data.imageURL)
    }

    func alignContent(to columnGuide: UILayoutGuide) {
        guard !isContentAligned else {
            assertionFailure(Constants.Detail.Log.contentAlreadyAligned)
            return
        }
        isContentAligned = true
        alignTextStack(to: columnGuide)
        installHeroConstraints(columnGuide: columnGuide)
        observeHorizontalSizeClass()
        updateTextTopConstraint()
    }

    func titleMaxY(in view: UIView) -> CGFloat {
        titleLabel.convert(titleLabel.bounds, to: view).maxY
    }
}
