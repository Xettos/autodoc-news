import Testing
@testable import AutodocNews

@MainActor
@Suite("NewsFeedViewModel", .timeLimit(.minutes(1)))
struct NewsFeedViewModelTests {
    private enum TestData {
        static let firstPage = Constants.API.firstPage
        static let secondPage = firstPage + 1
        static let thirdPage = secondPage + 1
        static let firstPageIDs = 1...15
        static let secondPageIDs = 16...30
        static let totalCount = 40
        static let lastVisibleIndex = 14
        static let earlyVisibleIndex = 9
        static let unknownID = 999
        static let selectedID = 3
    }

    private let context = NewsFeedTestContext(repository: StubNewsRepository())
    private var repository: StubNewsRepository { context.repository }
    private var viewModel: NewsFeedViewModel { context.viewModel }
    private var states: PublisherRecorder<NewsFeedViewState> { context.states }

    @Test("start shows the first page's items")
    func startShowsFirstPage() async throws {
        let state = try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)

        #expect(state.itemIDs == Array(TestData.firstPageIDs))
    }

    @Test("start requests the first page with the configured page size")
    func startRequestsFirstPage() async throws {
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)

        #expect(repository.news.calls == [TestData.firstPage])
        #expect(repository.pageSizes == [NewsFeedTestContext<StubNewsRepository>.pageSize])
    }

    @Test("a first page short of totalCount shows the loading footer")
    func firstPageShowsLoadingFooter() async throws {
        let state = try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)

        #expect(state.pagingFooter == .loading)
    }

    @Test("showing the first page bumps the content revision once")
    func firstPageBumpsRevision() async throws {
        let revisionBefore = viewModel.state.contentRevision

        let state = try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)

        #expect(state.contentRevision == revisionBefore + 1)
    }

    @Test("items and card view data are available by ID after loading")
    func exposesItemsByID() async throws {
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.firstPageIDs.count)

        #expect(viewModel.item(with: TestData.selectedID) == .fixture(id: TestData.selectedID))
        #expect(viewModel.viewData(for: TestData.selectedID)?.title == "Новость \(TestData.selectedID)")
        #expect(viewModel.item(with: TestData.unknownID) == nil)
    }

    @Test("empty first page shows the empty phase")
    func emptyFirstPage() async throws {
        repository.news.enqueue(.success(NewsPage(items: [], totalCount: 0)), for: TestData.firstPage)

        viewModel.start()
        let state = try await states.waitForLatest { $0.phase != .initialLoading }

        #expect(state.phase == .empty)
        #expect(state.pagingFooter == .hidden)
    }

    @Test("repeated start while the first page is in flight sends one request")
    func startIsIdempotent() async throws {
        viewModel.start()
        await repository.news.waitForPendingCall(for: TestData.firstPage)
        viewModel.start()
        repository.resolvePage(TestData.firstPage, ids: TestData.firstPageIDs, totalCount: TestData.firstPageIDs.count)

        try await states.waitForLatest { $0.phase == .content }
        viewModel.start()

        #expect(repository.news.calls == [TestData.firstPage])
    }

    @Test("first page failure shows the failed phase with the error description")
    func firstPageFailure() async throws {
        repository.stubPage(TestData.firstPage, failingWith: NetworkError.offline)
        let expectedMessage = try #require(NetworkError.offline.errorDescription)

        viewModel.start()
        let state = try await states.waitForLatest { $0.phase != .initialLoading }

        #expect(state.phase == .failed(message: expectedMessage))
    }

    @Test("reload after a first page failure shows the skeleton and then content")
    func reloadAfterFailure() async throws {
        repository.stubPage(TestData.firstPage, failingWith: NetworkError.timedOut)
        repository.stubPage(TestData.firstPage, ids: TestData.firstPageIDs, totalCount: TestData.firstPageIDs.count)
        viewModel.start()
        try await states.waitForLatest { $0.phase.isFailed }

        viewModel.reload()
        #expect(viewModel.state.phase == .initialLoading)
        let state = try await states.waitForLatest { $0.phase == .content }

        #expect(state.itemIDs == Array(TestData.firstPageIDs))
        #expect(repository.news.calls == [TestData.firstPage, TestData.firstPage])
    }

    @Test("reaching the threshold appends the next page without a content revision")
    func appendsNextPage() async throws {
        let firstState = try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        repository.stubPage(TestData.secondPage, ids: TestData.secondPageIDs, totalCount: TestData.totalCount)

        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        let state = try await states.waitForLatest { $0.itemIDs.count > TestData.firstPageIDs.count }

        #expect(state.itemIDs == Array(TestData.firstPageIDs.lowerBound...TestData.secondPageIDs.upperBound))
        #expect(state.pagingFooter == .loading)
        #expect(state.contentRevision == firstState.contentRevision)
    }

    @Test("the ViewModel asks the paging trigger with the visible index and the item count")
    func asksPagingTrigger() async throws {
        let context = NewsFeedTestContext(repository: StubNewsRepository(), pagingDecision: .never)
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)

        context.viewModel.loadMoreIfNeeded(visibleIndex: TestData.earlyVisibleIndex)

        let question = RecordingPagingTrigger.Question(visibleIndex: TestData.earlyVisibleIndex, itemCount: TestData.firstPageIDs.count)
        #expect(context.pagingTrigger.questions == [question])
    }

    @Test("a declined paging trigger starts no page load")
    func declinedTriggerStartsNoLoad() async throws {
        let context = NewsFeedTestContext(repository: StubNewsRepository(), pagingDecision: .never)
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)

        context.viewModel.loadMoreIfNeeded(visibleIndex: TestData.earlyVisibleIndex)
        context.viewModel.loadMoreIfNeeded(visibleIndex: TestData.earlyVisibleIndex)

        #expect(context.pagingTrigger.questions.count == 2)
    }

    @Test("items repeated across pages are shown once")
    func deduplicatesAcrossPages() async throws {
        let overlappingIDs = 11...25
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        repository.stubPage(TestData.secondPage, ids: overlappingIDs, totalCount: TestData.totalCount)

        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        let state = try await states.waitForLatest { $0.itemIDs.count > TestData.firstPageIDs.count }

        #expect(state.itemIDs == Array(TestData.firstPageIDs.lowerBound...overlappingIDs.upperBound))
    }

    @Test("a page made only of duplicates immediately loads the following page")
    func skipsDuplicateOnlyPage() async throws {
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        repository.stubPage(TestData.secondPage, ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        repository.stubPage(TestData.thirdPage, ids: TestData.secondPageIDs, totalCount: TestData.totalCount)

        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        let state = try await states.waitForLatest { $0.itemIDs.count > TestData.firstPageIDs.count }

        #expect(state.itemIDs == Array(TestData.firstPageIDs.lowerBound...TestData.secondPageIDs.upperBound))
        #expect(repository.news.calls == [TestData.firstPage, TestData.secondPage, TestData.thirdPage])
    }

    @Test("paging footer hides once totalCount is reached")
    func stopsAtTotalCount() async throws {
        let lastPageIDs = 16...20
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: lastPageIDs.upperBound)
        repository.stubPage(TestData.secondPage, ids: lastPageIDs, totalCount: lastPageIDs.upperBound)

        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        let state = try await states.waitForLatest { $0.itemIDs.count == lastPageIDs.upperBound }

        #expect(state.pagingFooter == .hidden)
    }

    @Test("paging footer hides after an empty page")
    func stopsAtEmptyPage() async throws {
        let firstItems = TestData.firstPageIDs.map { NewsItem.fixture(id: $0) }
        repository.news.enqueue(.success(NewsPage(items: firstItems, totalCount: nil)), for: TestData.firstPage)
        viewModel.start()
        try await states.waitForLatest { $0.phase == .content }
        repository.news.enqueue(.success(NewsPage(items: [], totalCount: nil)), for: TestData.secondPage)

        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        let state = try await states.waitForLatest { $0.pagingFooter == .hidden }

        #expect(state.itemIDs == Array(TestData.firstPageIDs))
    }

    @Test("first page equal to totalCount leaves nothing to load")
    func singlePageFeed() async throws {
        let state = try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.firstPageIDs.count)

        #expect(state.pagingFooter == .hidden)
    }

    @Test("the state publisher replays the current state to new subscribers")
    func statePublisherReplaysCurrentState() async throws {
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.firstPageIDs.count)

        let lateSubscriber = PublisherRecorder(viewModel.statePublisher)

        #expect(lateSubscriber.values == [viewModel.state])
    }

    @Test("state is already updated when subscribers receive it")
    func stateIsUpdatedBeforeDelivery() async throws {
        let observedStates = PublisherRecorder(viewModel.statePublisher.map { [viewModel] _ in
            MainActor.assumeIsolated { viewModel.state }
        })

        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.firstPageIDs.count)

        #expect(observedStates.values == states.values)
    }

    @Test("repeated threshold hits while a page is in flight send one request")
    func noConcurrentPageRequests() async throws {
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)

        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex - 2)
        await repository.news.waitForPendingCall(for: TestData.secondPage)
        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex - 1)
        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        repository.resolvePage(TestData.secondPage, ids: TestData.secondPageIDs, totalCount: TestData.totalCount)
        try await states.waitForLatest { $0.itemIDs.count > TestData.firstPageIDs.count }

        #expect(repository.news.calls == [TestData.firstPage, TestData.secondPage])
    }

    @Test("next page failure shows a failed footer and keeps items")
    func nextPageFailure() async throws {
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        repository.stubPage(TestData.secondPage, failingWith: NetworkError.httpStatus(502))
        let expectedMessage = try #require(NetworkError.httpStatus(502).errorDescription)

        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        let state = try await states.waitForLatest { $0.pagingFooter != .loading }

        #expect(state.pagingFooter == .failed(message: expectedMessage))
        #expect(state.itemIDs == Array(TestData.firstPageIDs))
        #expect(state.phase == .content)
    }

    @Test("retryNextPage after a failure loads the same page again")
    func retryNextPage() async throws {
        try await failSecondPage()
        repository.stubPage(TestData.secondPage, ids: TestData.secondPageIDs, totalCount: TestData.totalCount)

        viewModel.retryNextPage()
        #expect(viewModel.state.pagingFooter == .loading)
        let state = try await states.waitForLatest { $0.itemIDs.count > TestData.firstPageIDs.count }

        #expect(state.itemIDs == Array(TestData.firstPageIDs.lowerBound...TestData.secondPageIDs.upperBound))
        #expect(repository.news.calls == [TestData.firstPage, TestData.secondPage, TestData.secondPage])
    }

    @Test("a failed footer blocks automatic paging until the user retries")
    func failedFooterBlocksAutoPaging() async throws {
        try await failSecondPage()
        repository.stubPage(TestData.secondPage, ids: TestData.secondPageIDs, totalCount: TestData.totalCount)

        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        #expect(viewModel.state.pagingFooter.isFailed)
        viewModel.retryNextPage()
        try await states.waitForLatest { $0.itemIDs.count > TestData.firstPageIDs.count }

        #expect(repository.news.calls == [TestData.firstPage, TestData.secondPage, TestData.secondPage])
        repository.news.expectFullyConsumed()
    }

    @Test("retryNextPage without a failed footer does nothing")
    func retryWithoutFailureIsNoOp() async throws {
        let shownState = try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)

        viewModel.retryNextPage()

        #expect(viewModel.state == shownState)
        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        #expect(context.pagingTrigger.questions.count == 1)
    }

    @Test("selecting a loaded item emits an article route")
    func selectItemEmitsRoute() async throws {
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.firstPageIDs.count)
        let routes = PublisherRecorder(viewModel.routes)

        viewModel.selectItem(id: TestData.selectedID)

        #expect(routes.values == [.article(.fixture(id: TestData.selectedID))])
    }

    @Test("selecting an unknown ID emits nothing")
    func selectUnknownItem() async throws {
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.firstPageIDs.count)
        let routes = PublisherRecorder(viewModel.routes)

        viewModel.selectItem(id: TestData.unknownID)

        #expect(routes.values.isEmpty)
    }

    private func failSecondPage() async throws {
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        repository.stubPage(TestData.secondPage, failingWith: NetworkError.offline)
        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        try await states.waitForLatest { $0.pagingFooter.isFailed }
    }
}

extension NewsFeedViewState.Phase {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

extension NewsFeedViewState.PagingFooter {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
