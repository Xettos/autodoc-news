import Foundation
@testable import AutodocNews

enum TestError: Error, Equatable {
    case unexpected
}

extension NewsItem {
    static func fixture(
        id: ID,
        title: String? = nil,
        category: String = "Автомобильные новости",
        publishedAt: Date? = nil,
        imageURL: URL? = URL(string: "https://file.autodoc.ru/news/image.jpg")
    ) -> NewsItem {
        NewsItem(
            id: id,
            title: title ?? "Новость \(id)",
            summary: "Анонс новости \(id)",
            publishedAt: publishedAt,
            path: "avto-novosti/news_\(id)",
            webURL: URL(string: "https://www.autodoc.ru/company/news/avto-novosti/news_\(id)"),
            imageURL: imageURL,
            category: category
        )
    }
}

extension NewsPage {
    static func fixture(ids: [NewsItem.ID], totalCount: Int) -> NewsPage {
        NewsPage(items: ids.map { NewsItem.fixture(id: $0) }, totalCount: totalCount)
    }
}

extension NewsArticle {
    static func fixture(item: NewsItem = .fixture(id: 1), html: String = "<p>Текст статьи</p>") -> NewsArticle {
        NewsArticle(item: item, html: html)
    }
}

enum JSONFixtures {
    static let newsPage = #"""
    {
      "news": [
        {
          "id": 9073,
          "title": "Acura NEXERA Vision &mdash; юбилейный концепт ",
          "description": "Компания Acura подготовила для своих поклонников необычный подарок",
          "publishedDate": "2026-08-17T00:00:00",
          "url": "avto-novosti/acura_nexera",
          "fullUrl": "https://www.autodoc.ru/company/news/avto-novosti/acura_nexera",
          "titleImageUrl": "https://file.autodoc.ru/news/avto-novosti/3718066421_1.jpg",
          "categoryType": "Автомобильные новости"
        },
        {
          "id": 9078,
          "title": "Открытие магазина в г. Екатеринбург",
          "description": "г. Екатеринбург, ул. Белинского, д.222",
          "publishedDate": "2026-08-16T00:00:00",
          "url": "novosti-kompanii/20275",
          "fullUrl": "https://www.autodoc.ru/company/news/novosti-kompanii/20275",
          "titleImageUrl": "https://file.autodoc.ru/news/foto_magazinov/magazin_ekaterinburg_belinskogo.jpg",
          "categoryType": "Новости компании"
        }
      ],
      "totalCount": 1324
    }
    """#

    static let pageWithBrokenAndSparseItems = #"""
    {
      "news": [
        { "id": 1 },
        { "id": "not-a-number", "title": "Битый элемент" },
        { "title": "Без id" },
        {
          "id": 2,
          "title": null,
          "publishedDate": "вчера",
          "url": "/avto-novosti/sparse/",
          "fullUrl": "not a url",
          "titleImageUrl": "/relative/image.jpg"
        }
      ]
    }
    """#

    static let article = #"""
    {
      "id": 9073,
      "title": "Acura NEXERA Vision — юбилейный концепт",
      "description": "Компания Acura подготовила для своих поклонников необычный подарок",
      "text": "<p>\r\n\t<a class=\"photo photo-first\" href=\"https://file.autodoc.ru/news/avto-novosti/3718066421_1.jpg\"><img src=\"https://file.autodoc.ru/news/avto-novosti/3718066421_1.jpg\" /></a></p>\r\n<p>\r\n\tК 40-летнему юбилею компания Acura подготовила необычный подарок &mdash; концепт NEXERA Vision.</p>",
      "publishedDate": "2026-08-17T00:00:00",
      "url": "/avto-novosti/acura_nexera/",
      "fullUrl": "https://www.autodoc.ru/company/news/avto-novosti/acura_nexera/",
      "titleImageUrl": "https://file.autodoc.ru/news/avto-novosti/3718066421_1.jpg",
      "categoryType": "Автомобильные новости"
    }
    """#
}

extension Date {
    static func utc(_ string: String) throws -> Date {
        try Date.ISO8601FormatStyle(includingFractionalSeconds: string.contains(".")).parse(string)
    }
}
