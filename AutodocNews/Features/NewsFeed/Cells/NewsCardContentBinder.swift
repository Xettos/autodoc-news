import UIKit

@MainActor
protocol NewsCardContentBinding {
    func configureAccessibility()
    func bind(_ content: NewsCardContent, imageLoader: any ImageLoading)
    func reset()
    func cancelImageLoading()
}

@MainActor
struct NewsCardContentBinder: NewsCardContentBinding {
    unowned let cell: UICollectionViewCell
    let imageView: RemoteImageView
    let categoryBadge: BadgeLabel
    let titleLabel: UILabel
    let dateLabel: UILabel

    func configureAccessibility() {
        cell.isAccessibilityElement = true
        cell.accessibilityTraits = .button
    }

    func bind(_ content: NewsCardContent, imageLoader: any ImageLoading) {
        showText(content.viewData)
        imageView.setImage(content.imageRequest, using: imageLoader)
    }

    func reset() {
        showText(nil)
        imageView.cancelLoading()
    }

    func cancelImageLoading() {
        imageView.cancelLoading()
    }

    private func showText(_ viewData: NewsCardViewData?) {
        let category = viewData?.category ?? ""
        categoryBadge.text = category
        categoryBadge.isHidden = category.isEmpty
        titleLabel.text = viewData?.title
        dateLabel.text = viewData?.dateText
        cell.accessibilityLabel = viewData?.accessibilityLabel
    }
}
