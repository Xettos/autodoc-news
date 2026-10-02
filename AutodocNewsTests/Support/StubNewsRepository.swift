import os
@testable import AutodocNews

final class StubNewsRepository: NewsRepository {
    let news = ScriptedResponder<Int, NewsPage>()
    let articles = ScriptedResponder<String, NewsArticle>()

    private let requestedPageSizes = OSAllocatedUnfairLock(initialState: [Int]())

    var pageSizes: [Int] {
        requestedPageSizes.withLock { $0 }
    }

    func fetchNews(page: Int, pageSize: Int) async throws -> NewsPage {
        requestedPageSizes.withLock { $0.append(pageSize) }
        return try await news.respond(to: page)
    }

    func fetchArticle(path: String) async throws -> NewsArticle {
        try await articles.respond(to: path)
    }
}
