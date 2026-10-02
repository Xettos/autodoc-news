import UIKit

final class NewsFeaturedSkeletonCell: UICollectionViewCell {
    private let shimmerView = ShimmerView(cornerRadius: CornerRadius.card)

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityElementsHidden = true
        contentView.addSubviews(shimmerView)
        shimmerView.pinEdges(to: contentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
