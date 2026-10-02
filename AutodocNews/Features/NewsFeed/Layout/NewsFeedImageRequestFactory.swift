import UIKit

struct NewsCardImageSlot {
    let section: NewsFeedSection
    let itemSize: CGSize
    let traitCollection: UITraitCollection
}

@MainActor
protocol NewsFeedImageRequestMaking {
    func imageRequest(for url: URL, in slot: NewsCardImageSlot) -> ImageRequest
}

struct NewsFeedImageRequestFactory: NewsFeedImageRequestMaking {
    private let layoutProvider: any NewsFeedLayoutProviding

    init(layoutProvider: any NewsFeedLayoutProviding) {
        self.layoutProvider = layoutProvider
    }

    func imageRequest(for url: URL, in slot: NewsCardImageSlot) -> ImageRequest {
        let traits = slot.traitCollection
        let imageSize = layoutProvider.imageSize(forItemOfSize: slot.itemSize, in: slot.section, traitCollection: traits)
        return ImageRequest(url: url, targetSize: imageSize, scale: traits.displayScale)
    }
}
