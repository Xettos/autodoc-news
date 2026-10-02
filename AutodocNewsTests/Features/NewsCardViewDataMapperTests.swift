import Foundation
import Testing
@testable import AutodocNews

@Suite("NewsCardViewDataMapper")
struct NewsCardViewDataMapperTests {
    private let mapper = NewsCardViewDataMapper(dateFormatter: StubNewsDateFormatter(output: "17 августа 2026"))
    private let publishedAt = Date(timeIntervalSince1970: 0)

    @Test("copies title, category and image URL from the item")
    func copiesItemFields() {
        let item = NewsItem.fixture(id: 1, title: "Заголовок", category: "Тест-драйв")

        let viewData = mapper.viewData(for: item)

        #expect(viewData.title == "Заголовок")
        #expect(viewData.category == "Тест-драйв")
        #expect(viewData.imageURL == item.imageURL)
    }

    @Test("formats the publication date with the injected formatter")
    func formatsDate() {
        let item = NewsItem.fixture(id: 1, publishedAt: publishedAt)

        let viewData = mapper.viewData(for: item)

        #expect(viewData.dateText == "17 августа 2026")
    }

    @Test("missing publication date gives empty date text")
    func missingDate() {
        let viewData = mapper.viewData(for: .fixture(id: 1, publishedAt: nil))

        #expect(viewData.dateText.isEmpty)
    }

    @Test("accessibility label joins category, title and date")
    func accessibilityLabelJoinsParts() {
        let item = NewsItem.fixture(id: 1, title: "Заголовок", category: "Тест-драйв", publishedAt: publishedAt)

        let viewData = mapper.viewData(for: item)

        #expect(viewData.accessibilityLabel == "Тест-драйв, Заголовок, 17 августа 2026")
    }

    @Test("accessibility label skips empty parts")
    func accessibilityLabelSkipsEmptyParts() {
        let item = NewsItem.fixture(id: 1, title: "Заголовок", category: "", publishedAt: nil)

        let viewData = mapper.viewData(for: item)

        #expect(viewData.accessibilityLabel == "Заголовок")
    }
}
