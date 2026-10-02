import Foundation

protocol NewsFeedPagingTriggering: Sendable {
    func shouldLoadNextPage(visibleIndex: Int, itemCount: Int) -> Bool
}

struct NewsFeedPagingTrigger: NewsFeedPagingTriggering {
    let threshold: Int

    func shouldLoadNextPage(visibleIndex: Int, itemCount: Int) -> Bool {
        itemCount > 0 && visibleIndex >= itemCount - threshold
    }
}
