import Foundation

struct NewsImagePrefetch {
    let itemID: NewsItem.ID
    let request: ImageRequest
}

@MainActor
protocol NewsFeedImagePrefetching {
    func prefetch(_ prefetches: [NewsImagePrefetch])
    func cancelPrefetch(for itemIDs: [NewsItem.ID])
    func forgetIssuedRequests()
}

@MainActor
final class NewsFeedImagePrefetcher: NewsFeedImagePrefetching {
    private let imageLoader: any ImageLoading
    private var issuedRequests: [NewsItem.ID: ImageRequest] = [:]

    init(imageLoader: any ImageLoading) {
        self.imageLoader = imageLoader
    }

    func prefetch(_ prefetches: [NewsImagePrefetch]) {
        for prefetch in prefetches {
            issuedRequests[prefetch.itemID] = prefetch.request
        }
        imageLoader.prefetch(prefetches.map(\.request))
    }

    func cancelPrefetch(for itemIDs: [NewsItem.ID]) {
        let requests = itemIDs.compactMap { issuedRequests.removeValue(forKey: $0) }
        imageLoader.cancelPrefetch(requests)
    }

    func forgetIssuedRequests() {
        issuedRequests.removeAll()
    }
}
