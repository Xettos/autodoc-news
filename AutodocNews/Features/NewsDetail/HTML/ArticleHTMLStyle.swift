import Foundation

struct ArticleHTMLStyle: Equatable, Sendable {
    let lightLinkColor: CSSColor
    let darkLinkColor: CSSColor
}

extension ArticleHTMLStyle {
    struct CSSColor: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        var cssValue: String {
            String(
                format: Constants.Detail.CSS.rgbaFormat,
                Self.channel(red), Self.channel(green), Self.channel(blue),
                Self.clamped(alpha)
            )
        }

        private static func channel(_ value: Double) -> Int {
            Int((clamped(value) * Constants.Detail.CSS.colorChannelScale).rounded())
        }

        private static func clamped(_ value: Double) -> Double {
            value.isFinite ? min(max(value, 0), 1) : 1
        }
    }
}
