import Foundation

protocol NewsRepository: Sendable {
    func fetchNews(page: Int, pageSize: Int) async throws -> NewsPage
    func fetchArticle(path: String) async throws -> NewsArticle
}
