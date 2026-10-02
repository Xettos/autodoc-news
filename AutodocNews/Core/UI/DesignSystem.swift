import UIKit

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum CornerRadius {
    static let card: CGFloat = 16
    static let badge: CGFloat = 8
    static let image: CGFloat = 12
}

enum Palette {
    private typealias Alpha = Constants.UI.Alpha

    static let accent = UIColor(named: Constants.UI.ColorAsset.accent) ?? .systemBlue

    static let background = UIColor.systemBackground
    static let groupedBackground = UIColor.systemGroupedBackground
    static let cardBackground = UIColor.secondarySystemGroupedBackground
    static let imagePlaceholder = UIColor.tertiarySystemFill
    static let separator = UIColor.separator

    static let primaryText = UIColor.label
    static let secondaryText = UIColor.secondaryLabel
    static let tertiaryText = UIColor.tertiaryLabel

    static let overlayText = UIColor.white
    static let overlayBadgeBackground = UIColor.black.withAlphaComponent(Alpha.overlayBadge)

    static let badgeBackground = UIColor { traits in
        let alpha = traits.userInterfaceStyle == .dark ? Alpha.badgeTintDark : Alpha.badgeTintLight
        return accent.resolvedColor(with: traits).withAlphaComponent(alpha)
    }

    static let skeletonBase = UIColor.systemGray5
    static let skeletonHighlight = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemGray4.resolvedColor(with: traits)
            : .systemGray6.resolvedColor(with: traits)
    }
}

enum Typography {
    static let featuredTitle = font(.title2, weight: .bold)
    static let cardTitle = font(.subheadline, weight: .semibold)
    static let detailTitle = font(.title1, weight: .bold)
    static let body = font(.body)
    static let caption = font(.footnote)
    static let badge = font(.caption1, weight: .semibold)

    static func font(
        _ style: UIFont.TextStyle,
        weight: UIFont.Weight = .regular,
        maximumPointSize: CGFloat? = nil
    ) -> UIFont {
        let defaultTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let basePointSize = UIFont.preferredFont(forTextStyle: style, compatibleWith: defaultTraits).pointSize
        let weightedFont = UIFont.systemFont(ofSize: basePointSize, weight: weight)
        let metrics = UIFontMetrics(forTextStyle: style)
        guard let maximumPointSize else { return metrics.scaledFont(for: weightedFont) }
        return metrics.scaledFont(for: weightedFont, maximumPointSize: maximumPointSize)
    }
}
