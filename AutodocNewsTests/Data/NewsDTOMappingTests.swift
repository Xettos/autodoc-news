import Foundation
import Testing
@testable import AutodocNews

@Suite("News DTO decoding and mapping")
struct NewsDTOMappingTests {
    private let decoder = JSONDecoder()
    private let mapper = NewsDTOMapper.live

    @Test("decodes a real-shaped page with all items and totalCount")
    func decodesPage() throws {
        let page = try decoder.decode(NewsPageDTO.self, from: Data(JSONFixtures.newsPage.utf8))

        #expect(page.news.map(\.id) == [9073, 9078])
        #expect(page.totalCount == 1324)
    }

    @Test("skips items that cannot be decoded and keeps the rest")
    func skipsBrokenItems() throws {
        let page = try decoder.decode(NewsPageDTO.self, from: Data(JSONFixtures.pageWithBrokenAndSparseItems.utf8))

        #expect(page.news.map(\.id) == [1, 2])
        #expect(page.totalCount == nil)
    }

    @Test("missing news array decodes as an empty page")
    func missingNewsArray() throws {
        let page = try decoder.decode(NewsPageDTO.self, from: Data(#"{"totalCount": 0}"#.utf8))

        #expect(page.news.isEmpty)
    }

    @Test("article decodes item fields together with the HTML text")
    func decodesArticle() throws {
        let dto = try decoder.decode(NewsArticleDTO.self, from: Data(JSONFixtures.article.utf8))

        #expect(dto.item.id == 9073)
        #expect(dto.text?.hasPrefix("<p>") == true)
    }

    @Test("maps a complete item: entities decoded, title trimmed, date and URLs parsed")
    func mapsCompleteItem() throws {
        let dto = try #require(try decoder.decode(NewsPageDTO.self, from: Data(JSONFixtures.newsPage.utf8)).news.first)

        let item = try mapper.item(from: dto)

        #expect(item.title == "Acura NEXERA Vision — юбилейный концепт")
        #expect(item.category == "Автомобильные новости")
        #expect(item.path == "avto-novosti/acura_nexera")
        #expect(item.publishedAt == (try Date.utc("2026-08-16T21:00:00Z")))
        #expect(item.webURL?.absoluteString == "https://www.autodoc.ru/company/news/avto-novosti/acura_nexera")
        #expect(item.imageURL?.absoluteString == "https://file.autodoc.ru/news/avto-novosti/3718066421_1.jpg")
    }

    @Test("an item without a path cannot be opened and fails to map")
    func itemWithoutPathThrows() throws {
        let items = try decoder.decode(NewsPageDTO.self, from: Data(JSONFixtures.pageWithBrokenAndSparseItems.utf8)).news

        let itemWithoutPath = try #require(items.first)

        #expect(throws: NewsMappingError.missingPath) {
            try mapper.item(from: itemWithoutPath)
        }
    }

    @Test("maps missing or invalid optional fields to empty strings and nil")
    func mapsSparseItem() throws {
        let items = try decoder.decode(NewsPageDTO.self, from: Data(JSONFixtures.pageWithBrokenAndSparseItems.utf8)).news

        let sparse = try #require(items.dropFirst().first)

        let invalid = try mapper.item(from: sparse)

        #expect(invalid.title.isEmpty)
        #expect(invalid.path == "avto-novosti/sparse")
        #expect(invalid.publishedAt == nil)
        #expect(invalid.webURL == nil)
        #expect(invalid.imageURL == nil)
    }

    @Test("article path from the detail response loses its surrounding slashes")
    func trimsArticlePath() throws {
        let dto = try decoder.decode(NewsArticleDTO.self, from: Data(JSONFixtures.article.utf8))

        let article = try mapper.article(from: dto)

        #expect(article.item.path == "avto-novosti/acura_nexera")
        #expect(article.html == dto.text)
    }

    @Test("publication date comes from the injected parser")
    func usesInjectedDateParser() throws {
        let fixedDate = try Date.utc("2020-01-01T00:00:00Z")
        let mapper = NewsDTOMapper(dateParser: FixedNewsDateParser(date: fixedDate), entityDecoder: HTMLEntityDecoder())
        let dto = try #require(try decoder.decode(NewsPageDTO.self, from: Data(JSONFixtures.newsPage.utf8)).news.first)

        let item = try mapper.item(from: dto)

        #expect(item.publishedAt == fixedDate)
    }

    @Test("page mapping drops items without a path and keeps a missing totalCount unknown")
    func mapsPage() throws {
        let dto = try decoder.decode(NewsPageDTO.self, from: Data(JSONFixtures.pageWithBrokenAndSparseItems.utf8))

        let page = mapper.page(from: dto)

        #expect(page.items.map(\.id) == [2])
        #expect(page.totalCount == nil)
    }
}

@Suite("HTMLEntityDecoder")
struct HTMLEntityDecoderTests {
    private let entityDecoder = HTMLEntityDecoder()

    @Test("decodes named and numeric entities", arguments: [
        ("&quot;Автодок&quot; &amp; партнёры", "\"Автодок\" & партнёры"),
        ("&laquo;Новости&raquo; &mdash; итоги", "«Новости» — итоги"),
        ("&#169; 2026 &#x41;&#X42;", "© 2026 AB"),
        ("a&nbsp;b", "a\u{00A0}b"),
    ])
    func decodesKnownEntities(input: String, expected: String) {
        #expect(entityDecoder.decode(input) == expected)
    }

    @Test("leaves unknown, unterminated and invalid entities untouched", arguments: [
        "Tom & Jerry",
        "&unknown;",
        "&amp without semicolon",
        "&#xZZ;",
        "&#1114112;",
    ])
    func keepsUnrecognisedText(input: String) {
        #expect(entityDecoder.decode(input) == input)
    }
}
