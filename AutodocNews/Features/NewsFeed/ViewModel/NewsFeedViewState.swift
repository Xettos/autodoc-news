import Foundation

struct NewsFeedViewState: Equatable {
    enum Phase: Equatable {
        case initialLoading
        case content
        case empty
        case failed(message: String)
    }

    enum PagingFooter: Equatable {
        case hidden
        case loading
        case failed(message: String)
    }

    var itemIDs: [NewsItem.ID] = []
    var phase: Phase = .initialLoading
    var pagingFooter: PagingFooter = .hidden
    var isRefreshing = false
    var contentRevision = 0
}
