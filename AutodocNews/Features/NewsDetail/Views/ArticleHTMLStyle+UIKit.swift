import UIKit

extension ArticleHTMLStyle {
    init(accent: UIColor) {
        self.init(
            lightLinkColor: CSSColor(accent.resolved(for: .light)),
            darkLinkColor: CSSColor(accent.resolved(for: .dark))
        )
    }
}

private extension ArticleHTMLStyle.CSSColor {
    init(_ color: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
}

private extension UIColor {
    func resolved(for style: UIUserInterfaceStyle) -> UIColor {
        resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }
}
