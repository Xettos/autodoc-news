import Foundation

struct NewsFeedStore {
    private(set) var orderedIDs: [NewsItem.ID] = []
    private(set) var hasMore = false
    private(set) var lastAppendedCount = 0
    let pageSize: Int
    private var loadedPageCount = 0
    private var items: [NewsItem.ID: NewsItem] = [:]
    private var cardViewData: [NewsItem.ID: NewsCardViewData] = [:]
    private let viewDataMapper: any NewsCardViewDataMapping

    init(pageSize: Int, viewDataMapper: any NewsCardViewDataMapping) {
        self.pageSize = pageSize
        self.viewDataMapper = viewDataMapper
    }

    var isEmpty: Bool { orderedIDs.isEmpty }
    var nextPage: Int { loadedPageCount + Constants.API.firstPage }

    func item(with id: NewsItem.ID) -> NewsItem? {
        items[id]
    }

    func viewData(for id: NewsItem.ID) -> NewsCardViewData? {
        cardViewData[id]
    }

    mutating func reset() {
        self = NewsFeedStore(pageSize: pageSize, viewDataMapper: viewDataMapper)
    }

    mutating func replace(with firstPage: NewsPage) {
        reset()
        append(firstPage)
    }

    mutating func append(_ page: NewsPage) {
        loadedPageCount += 1
        let countBefore = orderedIDs.count
        for item in page.items where items[item.id] == nil {
            insert(item)
        }
        lastAppendedCount = orderedIDs.count - countBefore
        hasMore = Self.hasMore(after: page, loadedCount: orderedIDs.count, pageSize: pageSize)
    }

    private mutating func insert(_ item: NewsItem) {
        items[item.id] = item
        cardViewData[item.id] = viewDataMapper.viewData(for: item)
        orderedIDs.append(item.id)
    }

    private static func hasMore(after page: NewsPage, loadedCount: Int, pageSize: Int) -> Bool {
        guard !page.items.isEmpty else { return false }
        guard let totalCount = page.totalCount else { return page.items.count >= pageSize }
        return loadedCount < totalCount
    }
}
