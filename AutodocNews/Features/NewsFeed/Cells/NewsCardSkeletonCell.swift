import UIKit

final class NewsCardSkeletonCell: UICollectionViewCell {
    private typealias Skeleton = Constants.Feed.Layout.Skeleton

    private let imageBlock = ShimmerView(cornerRadius: CornerRadius.card)
    private let badgeBlock = ShimmerView()
    private let dateBlock = ShimmerView()
    private let titleBlocks = Skeleton.titleLineWidthRatios.map { _ in ShimmerView() }
    private let textArea = NewsCardTextArea()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureLayout()
        observeContentSizeCategory()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func configureAppearance() {
        CardShape.applyCardBackground(to: contentView)
        imageBlock.layer.maskedCorners = CardShape.topCorners
        accessibilityElementsHidden = true
    }

    private func configureLayout() {
        contentView.addSubviews(imageBlock, badgeBlock, dateBlock)
        titleBlocks.forEach { contentView.addSubviews($0) }
        textArea.install(in: contentView, below: imageBlock)
        layoutBadgeBlock()
        layoutTitleBlocks()
        layoutDateBlock()
    }

    private func layoutBadgeBlock() {
        let guide = textArea.guide
        NSLayoutConstraint.activate([
            badgeBlock.topAnchor.constraint(equalTo: guide.topAnchor, constant: Constants.Feed.Layout.Card.textInsets.top),
            badgeBlock.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            badgeBlock.widthAnchor.constraint(equalTo: guide.widthAnchor, multiplier: Skeleton.badgeWidthRatio),
            badgeBlock.heightAnchor.constraint(equalToConstant: Skeleton.badgeHeight)
        ])
    }

    private func layoutTitleBlocks() {
        var previousAnchor = badgeBlock.bottomAnchor
        for (block, widthRatio) in zip(titleBlocks, Skeleton.titleLineWidthRatios) {
            layoutTitleBlock(block, below: previousAnchor, widthRatio: widthRatio)
            previousAnchor = block.bottomAnchor
        }
    }

    private func layoutTitleBlock(_ block: UIView, below anchor: NSLayoutYAxisAnchor, widthRatio: CGFloat) {
        let guide = textArea.guide
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: anchor, constant: Skeleton.lineSpacing),
            block.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            block.widthAnchor.constraint(equalTo: guide.widthAnchor, multiplier: widthRatio),
            block.heightAnchor.constraint(equalToConstant: Skeleton.lineHeight)
        ])
    }

    private func layoutDateBlock() {
        let guide = textArea.guide
        NSLayoutConstraint.activate([
            dateBlock.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            dateBlock.bottomAnchor.constraint(
                equalTo: guide.bottomAnchor,
                constant: -Constants.Feed.Layout.Card.textInsets.bottom
            ),
            dateBlock.widthAnchor.constraint(equalTo: guide.widthAnchor, multiplier: Skeleton.dateWidthRatio),
            dateBlock.heightAnchor.constraint(equalToConstant: Skeleton.lineHeight)
        ])
    }

    private func observeContentSizeCategory() {
        textArea.updateHeight(for: traitCollection)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _: UITraitCollection) in
            self.textArea.updateHeight(for: self.traitCollection)
        }
    }
}
