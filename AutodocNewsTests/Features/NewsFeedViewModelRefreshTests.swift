import Testing
@testable import AutodocNews

@MainActor
@Suite("NewsFeedViewModel refresh and load races", .timeLimit(.minutes(1)))
struct NewsFeedViewModelRefreshTests {
    private enum TestData {
        static let firstPage = Constants.API.firstPage
        static let secondPage = firstPage + 1
        static let firstPageIDs = 1...15
        static let secondPageIDs = 16...30
        static let refreshedIDs = 101...115
        static let secondRefreshIDs = 201...215
        static let totalCount = 40
        static let lastVisibleIndex = 14
    }

    private let context = NewsFeedTestContext(repository: StubNewsRepository())
    private var repository: StubNewsRepository { context.repository }
    private var viewModel: NewsFeedViewModel { context.viewModel }
    private var states: PublisherRecorder<NewsFeedViewState> { context.states }

    @Test("refresh replaces items and bumps the content revision")
    func refreshReplacesItems() async throws {
        let shown = try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        repository.stubPage(TestData.firstPage, ids: TestData.refreshedIDs, totalCount: TestData.totalCount)

        viewModel.refresh()
        #expect(viewModel.state.isRefreshing)
        let state = try await states.waitForLatest { !$0.isRefreshing }

        #expect(state.itemIDs == Array(TestData.refreshedIDs))
        #expect(state.contentRevision == shown.contentRevision + 1)
        #expect(viewModel.item(with: TestData.firstPageIDs.lowerBound) == nil)
    }

    @Test("failed refresh keeps content and emits a message")
    func refreshFailureKeepsContent() async throws {
        try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        let messages = PublisherRecorder(viewModel.messages)
        repository.stubPage(TestData.firstPage, failingWith: NetworkError.offline)
        let expectedMessage = try #require(NetworkError.offline.errorDescription)

        viewModel.refresh()
        try await messages.wait { !$0.isEmpty }

        #expect(messages.values == [expectedMessage])
        let state = try #require(states.latest)
        #expect(state.itemIDs == Array(TestData.firstPageIDs))
        #expect(state.phase == .content)
        #expect(!state.isRefreshing)
    }

    @Test("refresh without content falls back to a full reload")
    func refreshWithoutContentReloads() async throws {
        repository.stubPage(TestData.firstPage, failingWith: NetworkError.offline)
        repository.stubPage(TestData.firstPage, ids: TestData.firstPageIDs, totalCount: TestData.firstPageIDs.count)
        viewModel.start()
        try await states.waitForLatest { $0.phase.isFailed }

        viewModel.refresh()
        let state = try await states.waitForLatest { $0.phase == .content }

        #expect(!state.isRefreshing)
        #expect(state.itemIDs == Array(TestData.firstPageIDs))
    }

    @Test("refresh while a refresh is in flight keeps the first one")
    func refreshWhileRefreshing() async throws {
        let shown = try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        viewModel.refresh()
        await repository.news.waitForPendingCall(for: TestData.firstPage)

        viewModel.refresh()

        #expect(repository.resolvePage(TestData.firstPage, ids: TestData.refreshedIDs, totalCount: TestData.totalCount))
        let state = try await states.waitForLatest { $0.contentRevision == shown.contentRevision + 1 }
        #expect(!state.isRefreshing)
        #expect(repository.news.calls == [TestData.firstPage, TestData.firstPage])
    }

    @Test("refresh during the initial load does not restart it")
    func refreshDuringInitialLoad() async throws {
        viewModel.start()
        await repository.news.waitForPendingCall(for: TestData.firstPage)

        viewModel.refresh()

        #expect(viewModel.state.phase == .initialLoading)
        #expect(repository.resolvePage(TestData.firstPage, ids: TestData.firstPageIDs, totalCount: TestData.totalCount))
        try await states.waitForLatest { $0.phase == .content }
        #expect(repository.news.calls == [TestData.firstPage])
    }

    @Test("failed refresh that interrupted paging restarts the next page load")
    func refreshFailureResumesPaging() async throws {
        try await startSecondPageLoad()
        repository.stubPage(TestData.firstPage, failingWith: NetworkError.offline)
        repository.stubPage(TestData.secondPage, ids: TestData.secondPageIDs, totalCount: TestData.totalCount)

        viewModel.refresh()
        let state = try await states.waitForLatest { $0.itemIDs.count > TestData.firstPageIDs.count }

        #expect(state.itemIDs == Array(TestData.firstPageIDs.lowerBound...TestData.secondPageIDs.upperBound))
        #expect(repository.news.calls == [TestData.firstPage, TestData.secondPage, TestData.firstPage, TestData.secondPage])
    }

    @Test("retrying the failed footer during a refresh neither cancels nor strands the refresh")
    func retryNextPageDuringRefresh() async throws {
        let shown = try await showFailedFooter()
        viewModel.refresh()
        await repository.news.waitForPendingCall(for: TestData.firstPage)

        viewModel.retryNextPage()

        #expect(repository.resolvePage(TestData.firstPage, ids: TestData.refreshedIDs, totalCount: TestData.totalCount))
        let refreshed = try await states.waitForLatest { $0.contentRevision == shown.contentRevision + 1 }
        #expect(!refreshed.isRefreshing)
        #expect(refreshed.itemIDs == Array(TestData.refreshedIDs))
    }

    @Test("a refresh after a retry attempted during refresh still sends a request")
    func refreshWorksAfterRetryDuringRefresh() async throws {
        let shown = try await showFailedFooter()
        viewModel.refresh()
        await repository.news.waitForPendingCall(for: TestData.firstPage)
        viewModel.retryNextPage()
        repository.resolvePage(TestData.firstPage, ids: TestData.refreshedIDs, totalCount: TestData.totalCount)
        try await states.waitForLatest { $0.contentRevision == shown.contentRevision + 1 }
        repository.stubPage(TestData.firstPage, ids: TestData.secondRefreshIDs, totalCount: TestData.totalCount)

        viewModel.refresh()

        let state = try await states.waitForLatest { $0.contentRevision == shown.contentRevision + 2 }
        #expect(state.itemIDs == Array(TestData.secondRefreshIDs))
        #expect(repository.news.calls == [TestData.firstPage, TestData.secondPage, TestData.firstPage, TestData.firstPage])
    }

    @Test("reload during paging cancels the page load and starts over without an error")
    func reloadDuringPaging() async throws {
        let shown = try await startSecondPageLoad()
        repository.stubPage(TestData.firstPage, ids: TestData.refreshedIDs, totalCount: TestData.totalCount)

        viewModel.reload()

        #expect(viewModel.state == NewsFeedViewState(contentRevision: shown.contentRevision))
        #expect(repository.news.pendingCallCount == 0)
        let state = try await states.waitForLatest { $0.phase == .content }
        #expect(state.itemIDs == Array(TestData.refreshedIDs))
        #expect(!states.values.contains { $0.pagingFooter.isFailed })
    }

    @Test("a page that arrives after refresh replaced its load is discarded")
    func lateResultOfReplacedLoadIsDiscarded() async throws {
        let context = NewsFeedTestContext(repository: NonCooperativeNewsRepository())
        let shown = try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        context.viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        await context.repository.news.waitForPendingCall(for: TestData.secondPage)
        context.viewModel.refresh()
        await context.repository.news.waitForPendingCall(for: TestData.firstPage)

        context.repository.resolvePage(TestData.secondPage, ids: TestData.secondPageIDs, totalCount: TestData.totalCount)
        try await context.repository.deliveredPages.wait(for: TestData.secondPage, count: 1)
        context.repository.resolvePage(TestData.firstPage, ids: TestData.refreshedIDs, totalCount: TestData.totalCount)

        let state = try await context.states.waitForLatest { $0.contentRevision == shown.contentRevision + 1 }
        #expect(state.itemIDs == Array(TestData.refreshedIDs))
        #expect(!state.isRefreshing)
        #expect(!context.states.values.contains { $0.itemIDs.contains(TestData.secondPageIDs.lowerBound) })
    }

    private func showFailedFooter() async throws -> NewsFeedViewState {
        let shown = try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        repository.stubPage(TestData.secondPage, failingWith: NetworkError.offline)
        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        try await states.waitForLatest { $0.pagingFooter.isFailed }
        return shown
    }

    @discardableResult
    private func startSecondPageLoad() async throws -> NewsFeedViewState {
        let shown = try await context.loadFirstPage(ids: TestData.firstPageIDs, totalCount: TestData.totalCount)
        viewModel.loadMoreIfNeeded(visibleIndex: TestData.lastVisibleIndex)
        await repository.news.waitForPendingCall(for: TestData.secondPage)
        return shown
    }
}
