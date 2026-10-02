import Testing
@testable import AutodocNews

@Suite("NewsFeedPagingTrigger")
struct NewsFeedPagingTriggerTests {
    private enum TestData {
        static let threshold = 5
        static let pageItemCount = 15
    }

    private let trigger = NewsFeedPagingTrigger(threshold: TestData.threshold)

    @Test("the next page loads once the visible item is within the threshold of the end", arguments: [
        (visibleIndex: 9, itemCount: TestData.pageItemCount, shouldLoad: false),
        (visibleIndex: 10, itemCount: TestData.pageItemCount, shouldLoad: true),
        (visibleIndex: 14, itemCount: TestData.pageItemCount, shouldLoad: true),
        (visibleIndex: 0, itemCount: 0, shouldLoad: false),
        (visibleIndex: 0, itemCount: 3, shouldLoad: true),
    ])
    func decision(visibleIndex: Int, itemCount: Int, shouldLoad: Bool) {
        #expect(trigger.shouldLoadNextPage(visibleIndex: visibleIndex, itemCount: itemCount) == shouldLoad)
    }
}
