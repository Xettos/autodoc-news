import UIKit

struct NewsCardMetrics: Equatable {
    private typealias Card = Constants.Feed.Layout.Card

    let textBlockHeight: CGFloat

    init(traitCollection: UITraitCollection) {
        textBlockHeight = Self.textBlockHeight(for: traitCollection)
    }

    func cardHeight(forWidth width: CGFloat) -> CGFloat {
        (width / Card.imageAspectRatio + textBlockHeight).rounded(.up)
    }

    func imageSize(inCardOf cardSize: CGSize) -> CGSize {
        CGSize(width: cardSize.width, height: max(0, cardSize.height - textBlockHeight))
    }

    private static func textBlockHeight(for traitCollection: UITraitCollection) -> CGFloat {
        let titleHeight = DynamicFontSpec.cardTitle.height(lines: Card.titleMaxLines, for: traitCollection)
        return Card.textInsets.top
            + DynamicFontSpec.badgeHeight(for: traitCollection)
            + Card.badgeToTitleSpacing
            + titleHeight
            + Card.titleToDateSpacing
            + DynamicFontSpec.dateHeight(for: traitCollection)
            + Card.textInsets.bottom
    }
}

extension NewsCardMetrics {
    @MainActor private static var cache: [UIContentSizeCategory: NewsCardMetrics] = [:]

    @MainActor
    static func metrics(for traitCollection: UITraitCollection) -> NewsCardMetrics {
        let category = traitCollection.preferredContentSizeCategory
        if let cached = cache[category] {
            return cached
        }
        let metrics = NewsCardMetrics(traitCollection: traitCollection)
        cache[category] = metrics
        return metrics
    }
}
