import Testing
@testable import AutodocNews

@Suite("NewsFeedStore")
struct NewsFeedStoreTests {
    private static func makeStore(pageSize: Int = 3) -> NewsFeedStore {
        NewsFeedStore(
            pageSize: pageSize,
            viewDataMapper: NewsCardViewDataMapper(dateFormatter: StubNewsDateFormatter())
        )
    }

    @Test("append adds only unseen IDs and reports how many were added")
    func appendSkipsDuplicates() {
        var store = Self.makeStore()
        store.append(.fixture(ids: [1, 2, 3], totalCount: 10))

        store.append(.fixture(ids: [3, 4, 2], totalCount: 10))

        #expect(store.lastAppendedCount == 1)
        #expect(store.orderedIDs == [1, 2, 3, 4])
        #expect(store.nextPage == 3)
    }

    @Test("append skips IDs repeated within one page")
    func appendSkipsDuplicatesWithinPage() {
        var store = Self.makeStore()

        store.append(.fixture(ids: [1, 1, 2], totalCount: 10))

        #expect(store.lastAppendedCount == 2)
        #expect(store.orderedIDs == [1, 2])
    }

    @Test("hasMore follows totalCount, empty pages and page fullness", arguments: [
        (ids: [1, 2, 3], totalCount: 10, hasMore: true),
        (ids: [1, 2, 3], totalCount: 3, hasMore: false),
        (ids: [], totalCount: 10, hasMore: false),
        (ids: [1, 2, 3], totalCount: nil, hasMore: true),
        (ids: [1, 2], totalCount: nil, hasMore: false),
    ] as [(ids: [Int], totalCount: Int?, hasMore: Bool)])
    func hasMore(ids: [Int], totalCount: Int?, hasMore: Bool) {
        var store = Self.makeStore()

        store.append(NewsPage(items: ids.map { NewsItem.fixture(id: $0) }, totalCount: totalCount))

        #expect(store.hasMore == hasMore)
    }

    @Test("appended items get card view data by ID")
    func appendMapsViewData() {
        var store = Self.makeStore()

        store.append(.fixture(ids: [7], totalCount: 10))

        #expect(store.viewData(for: 7)?.title == "Новость 7")
    }

    @Test("replace drops previous items and restarts paging")
    func replaceResets() {
        var store = Self.makeStore()
        store.append(.fixture(ids: [1, 2, 3], totalCount: 10))
        store.append(.fixture(ids: [4, 5, 6], totalCount: 10))

        store.replace(with: .fixture(ids: [7, 8, 9], totalCount: 10))

        #expect(store.orderedIDs == [7, 8, 9])
        #expect(store.nextPage == 2)
        #expect(store.item(with: 1) == nil)
        #expect(store.viewData(for: 1) == nil)
    }

    @Test("reset empties the store and keeps the page size")
    func resetKeepsPageSize() {
        var store = Self.makeStore(pageSize: 5)
        store.append(.fixture(ids: [1, 2, 3], totalCount: 10))

        store.reset()

        #expect(store.isEmpty)
        #expect(store.nextPage == 1)
        #expect(store.pageSize == 5)
    }
}
