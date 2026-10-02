import Foundation
import Testing
@testable import AutodocNews

@Suite("ArticleHTMLCleaner")
struct ArticleHTMLCleanerTests {
    private let cleaner = ArticleHTMLCleaner()
    private let heroURL: URL

    init() throws {
        heroURL = try #require(URL(string: "https://file.autodoc.ru/news/avto-novosti/hero.jpg"))
    }

    @Test("hero duplicate is removed together with its lightbox link and the emptied paragraph")
    func removesHeroWithWrapper() {
        let fragment = """
        <p>\r\n\t<a class="photo photo-first" href="https://file.autodoc.ru/news/avto-novosti/hero.jpg" rel="group2">\
        <img alt="Обложка" src="https://file.autodoc.ru/news/avto-novosti/hero.jpg" style="float:left" /></a></p>\
        <p>Текст новости</p>
        """

        let html = cleaner.cleanUp(fragment, removingImageAt: heroURL)

        #expect(html == "<p>Текст новости</p>")
    }

    @Test("hero is matched regardless of scheme and quote style", arguments: [
        #"<img src="//file.autodoc.ru/news/avto-novosti/hero.jpg">"#,
        #"<img src='http://file.autodoc.ru/news/avto-novosti/hero.jpg' />"#,
        #"<IMG class="x" SRC = "https://file.autodoc.ru/news/avto-novosti/hero.jpg">"#,
    ])
    func matchesHeroVariants(image: String) {
        let html = cleaner.cleanUp("\(image)<p>Текст</p>", removingImageAt: heroURL)

        #expect(html == "<p>Текст</p>")
    }

    @Test("hero with an escaped ampersand in the query is removed")
    func matchesEscapedAmpersand() throws {
        let url = try #require(URL(string: "https://file.autodoc.ru/img.jpg?w=1&h=2"))
        let fragment = #"<img src="https://file.autodoc.ru/img.jpg?w=1&amp;h=2"><p>Текст</p>"#

        #expect(cleaner.cleanUp(fragment, removingImageAt: url) == "<p>Текст</p>")
    }

    @Test("other images are kept")
    func keepsOtherImages() {
        let other = #"<p><img src="https://file.autodoc.ru/news/avto-novosti/other.jpg" /></p>"#
        let fragment = #"<p><img src="https://file.autodoc.ru/news/avto-novosti/hero.jpg" /></p>"# + other

        #expect(cleaner.cleanUp(fragment, removingImageAt: heroURL) == other)
    }

    @Test("an image whose URL only starts with the hero URL is kept")
    func keepsImageWithHeroPrefix() {
        let fragment = #"<img src="https://file.autodoc.ru/news/avto-novosti/hero.jpg.webp">"#

        #expect(cleaner.cleanUp(fragment, removingImageAt: heroURL) == fragment)
    }

    @Test("empty paragraphs and edge line breaks are cleaned", arguments: [
        ("<p>\r\n\t</p><p>Текст</p>", "<p>Текст</p>"),
        ("<div>&nbsp;<br /></div><p>Текст</p>", "<p>Текст</p>"),
        ("<br /><br>\n<p>Текст</p><br/>  ", "<p>Текст</p>"),
        ("<p class=\"x\">&#160;</p><p>Текст</p>", "<p>Текст</p>"),
    ])
    func cleansEmptyBlocks(fragment: String, expected: String) {
        #expect(cleaner.cleanUp(fragment, removingImageAt: nil) == expected)
    }

    @Test("a long whitespace run inside the text is kept, trailing breaks are removed")
    func keepsInnerWhitespace() {
        let fragment = "<p>Первый</p>" + String(repeating: " ", count: 2_000) + "<p>Второй</p><br/>\n"

        let html = cleaner.cleanUp(fragment, removingImageAt: nil)

        #expect(html == "<p>Первый</p>" + String(repeating: " ", count: 2_000) + "<p>Второй</p>")
    }

    @Test("every cleanup pattern compiles", arguments: [
        Constants.Detail.Cleaner.emptyBlockPattern,
        Constants.Detail.Cleaner.leadingLineBreaksPattern,
        Constants.Detail.Cleaner.trailingLineBreaksPattern,
        Constants.Detail.Cleaner.linkedImagePattern(
            image: Constants.Detail.Cleaner.imagePattern(
                source: Constants.Detail.Cleaner.imageSourcePattern(address: "file\\.autodoc\\.ru/a\\.jpg")
            )
        ),
    ])
    func patternCompiles(pattern: String) throws {
        _ = try NSRegularExpression(pattern: pattern)
    }

    @Test("content without a hero passes through unchanged")
    func passthrough() {
        let fragment = "<p>Первый</p><p><b>Второй</b> абзац</p>"

        #expect(cleaner.cleanUp(fragment, removingImageAt: nil) == fragment)
    }
}

@Suite("ArticleHTMLRenderer")
struct ArticleHTMLRendererTests {
    private let renderer = ArticleHTMLRenderer(cleaner: ArticleHTMLCleaner(), documentBuilder: ArticleHTMLDocumentBuilder())
    private let style = ArticleHTMLStyle(
        lightLinkColor: .init(red: 1, green: 0.5, blue: 0, alpha: 1),
        darkLinkColor: .init(red: 0, green: 0, blue: 1, alpha: 0.5)
    )

    @Test("wraps the cleaned fragment in a full page with CSP and link colors")
    func buildsPage() {
        let content = ArticleContent(
            fragment: #"<p><img src="https://file.autodoc.ru/hero.jpg"></p><p>Текст</p>"#,
            heroImageURL: URL(string: "https://file.autodoc.ru/hero.jpg")
        )

        let html = renderer.document(for: content, style: style)

        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("<body><p>Текст</p></body>"))
        #expect(!html.contains("hero.jpg"))
        #expect(html.contains(Constants.Detail.HTML.contentSecurityPolicy))
        #expect(html.contains("--link: rgba(255, 128, 0, 1.000);"))
        #expect(html.contains("--link: rgba(0, 0, 255, 0.500);"))
    }

    @Test("rendered document is the builder's page of the cleaner's output")
    func documentIsBuilderPageOfCleanedFragment() {
        let renderer = ArticleHTMLRenderer(cleaner: UppercasingCleaner(), documentBuilder: BodyOnlyBuilder())

        let html = renderer.document(for: ArticleContent(fragment: "<p>текст</p>", heroImageURL: nil), style: style)

        #expect(html == "<P>ТЕКСТ</P>")
    }

    @Test("CSS colors are clamped to valid numeric values", arguments: [
        (ArticleHTMLStyle.CSSColor(red: 1.2, green: -0.3, blue: 0.5, alpha: 2), "rgba(255, 0, 128, 1.000)"),
        (ArticleHTMLStyle.CSSColor(red: .nan, green: .infinity, blue: 0, alpha: .nan), "rgba(255, 255, 0, 1.000)"),
    ])
    func cssColorIsClamped(color: ArticleHTMLStyle.CSSColor, expected: String) {
        #expect(color.cssValue == expected)
    }
}

private struct UppercasingCleaner: ArticleHTMLCleaning {
    func cleanUp(_ fragment: String, removingImageAt imageURL: URL?) -> String {
        fragment.uppercased()
    }
}

private struct BodyOnlyBuilder: ArticleHTMLDocumentBuilding {
    func page(body: String, style: ArticleHTMLStyle) -> String {
        body
    }
}
