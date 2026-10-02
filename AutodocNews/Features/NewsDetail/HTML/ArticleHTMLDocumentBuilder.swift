import Foundation

protocol ArticleHTMLDocumentBuilding: Sendable {
    func page(body: String, style: ArticleHTMLStyle) -> String
}

struct ArticleHTMLDocumentBuilder: ArticleHTMLDocumentBuilding {
    func page(body: String, style: ArticleHTMLStyle) -> String {
        Constants.Detail.HTML.page(stylesheet: Self.stylesheet(for: style), body: body)
    }

    private static func stylesheet(for style: ArticleHTMLStyle) -> String {
        typealias CSS = Constants.Detail.CSS
        return [
            CSS.Rules.themeVariables(
                lightLink: style.lightLinkColor.cssValue,
                darkLink: style.darkLinkColor.cssValue
            ),
            CSS.Rules.body,
            CSS.Rules.cmsReset,
            CSS.Rules.text,
            CSS.Rules.media,
            CSS.Rules.blocks
        ].joined(separator: CSS.ruleBlockSeparator)
    }
}
