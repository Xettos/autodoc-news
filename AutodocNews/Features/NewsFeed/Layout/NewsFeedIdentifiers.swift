import Foundation

enum NewsFeedSection: Hashable, Sendable {
    case featured
    case feed
    case paging
}

enum NewsFeedItem: Hashable, Sendable {
    case news(NewsItem.ID)
    case placeholder(Int)
    case pagingLoading
    case pagingFailed
}
