import UIKit
import Testing
@testable import AutodocNews

@Suite("NewsFeedGrid")
struct NewsFeedGridTests {
    @Test("column count grows with container width", arguments: [
        (width: 320.0, columns: 1),
        (width: 599.0, columns: 1),
        (width: 600.0, columns: 2),
        (width: 899.0, columns: 2),
        (width: 900.0, columns: 3),
        (width: 1249.0, columns: 3),
        (width: 1250.0, columns: 4),
        (width: 2000.0, columns: 4),
    ])
    func columnCount(width: CGFloat, columns: Int) {
        #expect(NewsFeedGrid(containerWidth: width).columnCount == columns)
    }

    @Test("single column uses narrow insets and is not wide")
    func compactInsets() {
        let grid = NewsFeedGrid(containerWidth: 390)

        #expect(grid.horizontalInset == Spacing.l)
        #expect(!grid.isWide)
    }

    @Test("multi-column grid uses wide insets")
    func wideInsets() {
        let grid = NewsFeedGrid(containerWidth: 1000)

        #expect(grid.horizontalInset == Spacing.xl)
        #expect(grid.isWide)
    }

    @Test("item width subtracts insets and spacing and rounds down", arguments: [
        (width: 390.0, itemWidth: 358.0),
        (width: 1000.0, itemWidth: 306.0),
        (width: 10.0, itemWidth: 0.0),
    ])
    func itemWidth(width: CGFloat, itemWidth: CGFloat) {
        #expect(NewsFeedGrid(containerWidth: width).itemWidth == itemWidth)
    }

    @Test("content width never goes negative")
    func contentWidthIsClamped() {
        #expect(NewsFeedGrid(containerWidth: 10).contentWidth == 0)
    }
}

@Suite("NewsFeedSnapshotBuilder")
struct NewsFeedSnapshotBuilderTests {
    private let builder = NewsFeedSnapshotBuilder()

    @Test("initial loading shows a featured and eight feed placeholders")
    func placeholders() {
        let snapshot = builder.snapshot(for: NewsFeedViewState())

        #expect(snapshot.sectionIdentifiers == [.featured, .feed])
        #expect(snapshot.itemIdentifiers(inSection: .featured) == [.placeholder(0)])
        #expect(snapshot.itemIdentifiers(inSection: .feed).count == 8)
    }

    @Test("content splits the first item into the featured section and adds the paging footer")
    func content() {
        let state = NewsFeedViewState(itemIDs: [1, 2, 3], phase: .content, pagingFooter: .failed(message: "Ошибка"))

        let snapshot = builder.snapshot(for: state)

        #expect(snapshot.itemIdentifiers(inSection: .featured) == [.news(1)])
        #expect(snapshot.itemIdentifiers(inSection: .feed) == [.news(2), .news(3)])
        #expect(snapshot.itemIdentifiers(inSection: .paging) == [.pagingFailed])
    }

    @Test("hidden paging footer adds no paging section")
    func noPagingSection() {
        let state = NewsFeedViewState(itemIDs: [1, 2], phase: .content, pagingFooter: .hidden)

        let snapshot = builder.snapshot(for: state)

        #expect(snapshot.sectionIdentifiers == [.featured, .feed])
    }

    @Test("empty and failed phases produce an empty snapshot", arguments: [
        NewsFeedViewState.Phase.empty, .failed(message: "Ошибка"),
    ])
    func emptySnapshot(phase: NewsFeedViewState.Phase) {
        let snapshot = builder.snapshot(for: NewsFeedViewState(phase: phase))

        #expect(snapshot.numberOfItems == 0)
    }

    @Test("a next page is appended to the grid and the footer is kept")
    func appendsNextPage() throws {
        let previous = contentState(itemIDs: [1, 2, 3], footer: .loading)
        let current = contentState(itemIDs: [1, 2, 3, 4, 5], footer: .loading)

        let snapshot = try #require(appending(from: previous, to: current))

        #expect(snapshot.itemIdentifiers(inSection: .featured) == [.news(1)])
        #expect(snapshot.itemIdentifiers(inSection: .feed) == [2, 3, 4, 5].map(NewsFeedItem.news))
        #expect(snapshot.itemIdentifiers(inSection: .paging) == [.pagingLoading])
    }

    @Test("appending matches a full rebuild of the new state")
    func appendingEqualsFullBuild() throws {
        let previous = contentState(itemIDs: [1, 2, 3], footer: .loading)
        let current = contentState(itemIDs: [1, 2, 3, 4], footer: .hidden)

        let snapshot = try #require(appending(from: previous, to: current))

        #expect(snapshot.sectionIdentifiers == builder.snapshot(for: current).sectionIdentifiers)
        #expect(snapshot.itemIdentifiers == builder.snapshot(for: current).itemIdentifiers)
    }

    @Test("the paging footer is replaced by the new footer", arguments: [
        (NewsFeedViewState.PagingFooter.failed(message: "Ошибка"), [NewsFeedItem.pagingFailed]),
        (.hidden, []),
    ])
    func replacesFooter(footer: NewsFeedViewState.PagingFooter, expectedItems: [NewsFeedItem]) throws {
        let previous = contentState(itemIDs: [1, 2], footer: .loading)
        let current = contentState(itemIDs: [1, 2], footer: footer)

        let snapshot = try #require(appending(from: previous, to: current))

        let pagingItems = snapshot.sectionIdentifiers.contains(.paging) ? snapshot.itemIdentifiers(inSection: .paging) : []
        #expect(pagingItems == expectedItems)
    }

    @Test("a first item arriving into an empty feed goes to the featured section")
    func appendsIntoFeaturedRoom() throws {
        let previous = contentState(itemIDs: [], footer: .loading)
        let current = contentState(itemIDs: [1, 2], footer: .loading)

        let snapshot = try #require(appending(from: previous, to: current))

        #expect(snapshot.itemIdentifiers(inSection: .featured) == [.news(1)])
        #expect(snapshot.itemIdentifiers(inSection: .feed) == [.news(2)])
    }

    @Test("a change that is not a pure append needs a full rebuild", arguments: [
        AppendRejection.newRevision, .reordered, .phaseChanged, .noPreviousState,
    ])
    func rejectsNonAppends(rejection: AppendRejection) {
        let previous = contentState(itemIDs: [1, 2, 3], footer: .loading)
        let shown = builder.snapshot(for: previous)

        #expect(builder.appending(to: shown, transition: rejection.transition(from: previous)) == nil)
    }

    @Test("a snapshot that does not show the previous state needs a full rebuild")
    func rejectsStaleSnapshot() {
        let previous = contentState(itemIDs: [1, 2, 3], footer: .loading)
        let current = contentState(itemIDs: [1, 2, 3, 4], footer: .loading)
        let staleSnapshot = builder.snapshot(for: contentState(itemIDs: [1, 2], footer: .loading))

        let transition = NewsFeedStateTransition(previous: previous, current: current)

        #expect(builder.appending(to: staleSnapshot, transition: transition) == nil)
    }

    @Test("index path maps to the position in itemIDs")
    func itemIndex() {
        #expect(builder.itemIndex(for: IndexPath(item: 0, section: 0), in: .featured) == 0)
        #expect(builder.itemIndex(for: IndexPath(item: 2, section: 1), in: .feed) == 3)
        #expect(builder.itemIndex(for: IndexPath(item: 0, section: 2), in: .paging) == nil)
    }

    private func contentState(itemIDs: [NewsItem.ID], footer: NewsFeedViewState.PagingFooter) -> NewsFeedViewState {
        NewsFeedViewState(itemIDs: itemIDs, phase: .content, pagingFooter: footer)
    }

    private func appending(from previous: NewsFeedViewState, to current: NewsFeedViewState) -> NewsFeedSnapshot? {
        builder.appending(to: builder.snapshot(for: previous), transition: NewsFeedStateTransition(previous: previous, current: current))
    }
}

enum AppendRejection: CaseIterable, Sendable {
    case newRevision
    case reordered
    case phaseChanged
    case noPreviousState

    func transition(from previous: NewsFeedViewState) -> NewsFeedStateTransition {
        var current = previous
        switch self {
        case .newRevision:
            current.contentRevision += 1
        case .reordered:
            current.itemIDs = previous.itemIDs.reversed()
        case .phaseChanged:
            current.phase = .empty
        case .noPreviousState:
            return NewsFeedStateTransition(previous: nil, current: current)
        }
        return NewsFeedStateTransition(previous: previous, current: current)
    }
}

@MainActor
@Suite("NewsCardMetrics")
struct NewsCardMetricsTests {
    private enum TestData {
        static let narrowWidth: CGFloat = 320
        static let wideWidth: CGFloat = 640
        static let tinyCard = CGSize(width: 100, height: 1)
    }

    private let metrics = NewsCardMetrics(traitCollection: UITraitCollection(preferredContentSizeCategory: .large))

    @Test("a card is taller than its text block and grows with its width")
    func cardHeightGrowsWithWidth() {
        let narrow = metrics.cardHeight(forWidth: TestData.narrowWidth)
        let wide = metrics.cardHeight(forWidth: TestData.wideWidth)

        #expect(narrow > metrics.textBlockHeight)
        #expect(wide > narrow)
    }

    @Test("card heights are whole points, so grid rows line up")
    func cardHeightIsWholePoints() {
        let height = metrics.cardHeight(forWidth: TestData.narrowWidth)

        #expect(height == height.rounded())
    }

    @Test("the image never gets a negative height in a card shorter than its text block")
    func imageHeightIsClamped() {
        #expect(metrics.imageSize(inCardOf: TestData.tinyCard) == CGSize(width: TestData.tinyCard.width, height: 0))
    }

    @Test("a larger Dynamic Type size makes the text block taller", arguments: [
        UIContentSizeCategory.extraLarge, .accessibilityMedium, .accessibilityExtraExtraExtraLarge,
    ])
    func textBlockGrowsWithDynamicType(category: UIContentSizeCategory) {
        let larger = NewsCardMetrics(traitCollection: UITraitCollection(preferredContentSizeCategory: category))

        #expect(larger.textBlockHeight > metrics.textBlockHeight)
    }

    @Test("metrics are cached per content size category")
    func metricsAreCachedPerCategory() {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)

        #expect(NewsCardMetrics.metrics(for: traits) == metrics)
    }
}

@MainActor
@Suite("NewsFeedLayoutProvider")
struct NewsFeedLayoutProviderTests {
    private enum TestData {
        static let itemSize = CGSize(width: 300, height: 400)
        static let defaultCategory = UIContentSizeCategory.large
        static let largerCategory = UIContentSizeCategory.accessibilityExtraExtraExtraLarge
        static let sections: [NewsFeedSection] = [.featured, .feed]
        static let feedRowCount = 2
    }

    private let provider = NewsFeedLayoutProvider()

    @Test("featured image fills the whole item")
    func featuredImageSize() {
        let size = provider.imageSize(forItemOfSize: TestData.itemSize, in: .featured, traitCollection: traits(TestData.defaultCategory))

        #expect(size == TestData.itemSize)
    }

    @Test("feed card image keeps the card width and leaves room for the text block below it")
    func feedImageLeavesRoomForText() {
        let size = provider.imageSize(forItemOfSize: TestData.itemSize, in: .feed, traitCollection: traits(TestData.defaultCategory))

        #expect(size.width == TestData.itemSize.width)
        #expect(size.height > 0)
        #expect(size.height < TestData.itemSize.height)
    }

    @Test("a larger Dynamic Type size leaves a smaller image in the same card")
    func largerTextShrinksImage() {
        let regular = provider.imageSize(forItemOfSize: TestData.itemSize, in: .feed, traitCollection: traits(TestData.defaultCategory))
        let large = provider.imageSize(forItemOfSize: TestData.itemSize, in: .feed, traitCollection: traits(TestData.largerCategory))

        #expect(large.height < regular.height)
    }

    @Test("every feed card is one grid column wide and stays inside the container", arguments: [
        CGSize(width: 390, height: 844),
        CGSize(width: 820, height: 1180),
        CGSize(width: 1180, height: 820),
        CGSize(width: 1366, height: 1024),
    ])
    func feedCardsFitGridColumns(containerSize: CGSize) throws {
        let grid = NewsFeedGrid(containerWidth: containerSize.width)
        let frames = try layOutFeedCards(in: containerSize, count: grid.columnCount * TestData.feedRowCount)

        let contentRange = grid.horizontalInset...(containerSize.width - grid.horizontalInset)
        #expect(frames.map(\.width) == Array(repeating: grid.itemWidth, count: frames.count))
        #expect(frames.filter { !contentRange.contains($0.minX) || !contentRange.contains($0.maxX) }.isEmpty)
    }

    @Test("a feed row holds one card per grid column", arguments: [
        CGSize(width: 820, height: 1180),
        CGSize(width: 1366, height: 1024),
    ])
    func feedRowHoldsColumnCountCards(containerSize: CGSize) throws {
        let grid = NewsFeedGrid(containerWidth: containerSize.width)
        let frames = try layOutFeedCards(in: containerSize, count: grid.columnCount * TestData.feedRowCount)

        let rowOrigins = Set(frames.map(\.minY))
        #expect(rowOrigins.count == TestData.feedRowCount)
        #expect(Set(frames.map(\.minX)).count == grid.columnCount)
    }

    private func traits(_ category: UIContentSizeCategory) -> UITraitCollection {
        UITraitCollection(preferredContentSizeCategory: category)
    }

    private func layOutFeedCards(in containerSize: CGSize, count: Int) throws -> [CGRect] {
        let feedSection = try #require(TestData.sections.firstIndex(of: .feed))
        let dataSource = SectionCountDataSource(itemCounts: [Constants.Feed.Layout.Sections.featuredItemCount, count])
        let layout = provider.makeLayout { TestData.sections.indices.contains($0) ? TestData.sections[$0] : nil }
        let collectionView = UICollectionView(frame: CGRect(origin: .zero, size: containerSize), collectionViewLayout: layout)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: SectionCountDataSource.reuseIdentifier)
        collectionView.dataSource = dataSource
        collectionView.layoutIfNeeded()

        return try (0..<count).map { item in
            let attributes = layout.layoutAttributesForItem(at: IndexPath(item: item, section: feedSection))
            return try #require(attributes).frame
        }
    }
}

@MainActor
private final class SectionCountDataSource: NSObject, UICollectionViewDataSource {
    static let reuseIdentifier = "cell"

    private let itemCounts: [Int]

    init(itemCounts: [Int]) {
        self.itemCounts = itemCounts
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        itemCounts.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        itemCounts.indices.contains(section) ? itemCounts[section] : 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueReusableCell(withReuseIdentifier: Self.reuseIdentifier, for: indexPath)
    }
}
