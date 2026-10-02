import Foundation

struct NewsItem: Identifiable, Hashable, Sendable {
    typealias ID = Int

    let id: ID
    let title: String
    let summary: String
    let publishedAt: Date?
    let path: String
    let webURL: URL?
    let imageURL: URL?
    let category: String
}

struct NewsArticle: Hashable, Sendable {
    let item: NewsItem
    let html: String
}

struct NewsPage: Equatable, Sendable {
    let items: [NewsItem]
    let totalCount: Int?
}
