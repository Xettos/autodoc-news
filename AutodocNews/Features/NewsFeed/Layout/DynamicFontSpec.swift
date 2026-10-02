import UIKit

struct DynamicFontSpec: Sendable {
    let style: UIFont.TextStyle
    let weight: UIFont.Weight

    func lineHeight(for traitCollection: UITraitCollection) -> CGFloat {
        let defaultTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let basePointSize = UIFont.preferredFont(forTextStyle: style, compatibleWith: defaultTraits).pointSize
        let baseFont = UIFont.systemFont(ofSize: basePointSize, weight: weight)
        let font = UIFontMetrics(forTextStyle: style).scaledFont(for: baseFont, compatibleWith: traitCollection)
        return font.lineHeight
    }

    func height(lines: Int, for traitCollection: UITraitCollection) -> CGFloat {
        (lineHeight(for: traitCollection) * CGFloat(lines)).rounded(.up)
    }
}

extension DynamicFontSpec {
    static let badge = DynamicFontSpec(style: .caption1, weight: .semibold)
    static let cardTitle = DynamicFontSpec(style: .subheadline, weight: .semibold)
    static let featuredTitle = DynamicFontSpec(style: .title2, weight: .bold)
    static let caption = DynamicFontSpec(style: .footnote, weight: .regular)
}

extension DynamicFontSpec {
    static func badgeHeight(for traitCollection: UITraitCollection) -> CGFloat {
        badge.height(lines: 1, for: traitCollection) + Constants.Feed.Layout.Badge.verticalPadding
    }

    static func dateHeight(for traitCollection: UITraitCollection) -> CGFloat {
        caption.height(lines: 1, for: traitCollection)
    }
}
