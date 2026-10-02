import Foundation

struct ArticleContent: Equatable, Sendable {
    let fragment: String
    let heroImageURL: URL?
}

protocol ArticleHTMLRendering: Sendable {
    func document(for content: ArticleContent, style: ArticleHTMLStyle) -> String
}

extension ArticleHTMLRendering {
    @concurrent
    func renderDocument(for content: ArticleContent, style: ArticleHTMLStyle) async -> String {
        document(for: content, style: style)
    }
}

struct ArticleHTMLRenderer: ArticleHTMLRendering {
    private let cleaner: any ArticleHTMLCleaning
    private let documentBuilder: any ArticleHTMLDocumentBuilding

    init(cleaner: any ArticleHTMLCleaning, documentBuilder: any ArticleHTMLDocumentBuilding) {
        self.cleaner = cleaner
        self.documentBuilder = documentBuilder
    }

    func document(for content: ArticleContent, style: ArticleHTMLStyle) -> String {
        let body = cleaner.cleanUp(content.fragment, removingImageAt: content.heroImageURL)
        return documentBuilder.page(body: body, style: style)
    }
}
