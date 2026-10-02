import UIKit

struct NewsCardContent {
    let viewData: NewsCardViewData
    let imageRequest: ImageRequest?
}

@MainActor
protocol NewsCardDisplaying: UICollectionViewCell {
    var transitionSourceView: UIView { get }

    func configure(with content: NewsCardContent, imageLoader: any ImageLoading)
    func resetContent()
}
