import UIKit

@MainActor
enum NewsFeaturedMetrics {
    private typealias Featured = Constants.Feed.Layout.Featured

    private static var minimumHeightCache: [UIContentSizeCategory: CGFloat] = [:]

    static func height(forWidth width: CGFloat, isWide: Bool, traitCollection: UITraitCollection) -> CGFloat {
        let aspectRatio = isWide ? Featured.wideAspectRatio : Featured.compactAspectRatio
        let naturalHeight = min(width / aspectRatio, Featured.maximumHeight)
        return max(naturalHeight, minimumHeight(for: traitCollection)).rounded(.up)
    }

    private static func minimumHeight(for traitCollection: UITraitCollection) -> CGFloat {
        let category = traitCollection.preferredContentSizeCategory
        if let cached = minimumHeightCache[category] {
            return cached
        }
        let height = computeMinimumHeight(for: traitCollection)
        minimumHeightCache[category] = height
        return height
    }

    private static func computeMinimumHeight(for traitCollection: UITraitCollection) -> CGFloat {
        let titleHeight = DynamicFontSpec.featuredTitle.height(lines: Featured.titleMaxLines, for: traitCollection)
        return Featured.minimumImageReveal
            + Featured.textInsets.top
            + DynamicFontSpec.badgeHeight(for: traitCollection)
            + Featured.interitemSpacing
            + titleHeight
            + Featured.interitemSpacing
            + DynamicFontSpec.dateHeight(for: traitCollection)
            + Featured.textInsets.bottom
    }
}
