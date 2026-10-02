import Combine
import Foundation
import os

@MainActor
final class NewsFeedViewModel: NewsFeedViewModelProtocol {
    struct Dependencies {
        let repository: any NewsRepository
        let viewDataMapper: any NewsCardViewDataMapping
        let pagingTrigger: any NewsFeedPagingTriggering
        let errorMessages: any ErrorMessageMapping
    }

    private enum LoadKind {
        case firstPage
        case refresh(RefreshMode)
        case nextPage
    }

    private enum RefreshMode {
        case standalone
        case interruptingPaging
    }

    private struct PageLoad {
        let kind: LoadKind
        let page: Int
        let pageSize: Int
    }

    private typealias Log = Constants.Feed.Log

    private static let logger = Logger(subsystem: Constants.App.Log.subsystem, category: Log.viewModelCategory)

    private(set) var state: NewsFeedViewState {
        get { stateSubject.value }
        set { stateSubject.value = newValue }
    }

    var statePublisher: AnyPublisher<NewsFeedViewState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var routes: AnyPublisher<NewsFeedRoute, Never> {
        routeSubject.eraseToAnyPublisher()
    }

    var messages: AnyPublisher<String, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    private let repository: any NewsRepository
    private let pagingTrigger: any NewsFeedPagingTriggering
    private let errorMessages: any ErrorMessageMapping
    private var store: NewsFeedStore
    private var loadTask: Task<Void, Never>?
    private var activeLoad: PageLoad?
    private let stateSubject = CurrentValueSubject<NewsFeedViewState, Never>(NewsFeedViewState())
    private let routeSubject = PassthroughSubject<NewsFeedRoute, Never>()
    private let messageSubject = PassthroughSubject<String, Never>()

    init(dependencies: Dependencies, pageSize: Int) {
        precondition(pageSize > 0, Constants.Feed.Diagnostics.nonPositivePageSize)
        repository = dependencies.repository
        pagingTrigger = dependencies.pagingTrigger
        errorMessages = dependencies.errorMessages
        store = NewsFeedStore(pageSize: pageSize, viewDataMapper: dependencies.viewDataMapper)
    }

    deinit {
        loadTask?.cancel()
    }

    func item(with id: NewsItem.ID) -> NewsItem? {
        store.item(with: id)
    }

    func viewData(for id: NewsItem.ID) -> NewsCardViewData? {
        store.viewData(for: id)
    }

    func start() {
        guard state.phase == .initialLoading, store.isEmpty, !isLoading else { return }
        startLoading(.firstPage)
    }

    func refresh() {
        switch state.phase {
        case .content:
            startRefresh()
        case .initialLoading where isLoading:
            return
        case .initialLoading, .empty, .failed:
            reload()
        }
    }

    func reload() {
        store.reset()
        state = NewsFeedViewState(contentRevision: state.contentRevision)
        startLoading(.firstPage)
    }

    func retryNextPage() {
        guard case .failed = state.pagingFooter, !state.isRefreshing else { return }
        state.pagingFooter = .loading
        startLoading(.nextPage)
    }

    func loadMoreIfNeeded(visibleIndex: Int) {
        let itemCount = state.itemIDs.count
        guard canLoadNextPage, pagingTrigger.shouldLoadNextPage(visibleIndex: visibleIndex, itemCount: itemCount) else {
            return
        }
        startLoading(.nextPage)
    }

    func selectItem(id: NewsItem.ID) {
        guard let item = store.item(with: id) else { return }
        routeSubject.send(.article(item))
    }

    private var isLoading: Bool { activeLoad != nil }

    private var canLoadNextPage: Bool {
        state.phase == .content && state.pagingFooter == .loading && !isLoading
    }

    private func startRefresh() {
        guard !state.isRefreshing else { return }
        let mode: RefreshMode = isLoading ? .interruptingPaging : .standalone
        state.isRefreshing = true
        startLoading(.refresh(mode))
    }

    private func startLoading(_ kind: LoadKind) {
        cancelActiveLoad()
        let load = pageLoad(for: kind)
        activeLoad = load
        loadTask = Task { [weak self, repository] in
            let result = await Result { try await repository.fetchNews(page: load.page, pageSize: load.pageSize) }
            guard !Task.isCancelled else { return }
            self?.finishLoading(load, with: result)
        }
    }

    private func cancelActiveLoad() {
        loadTask?.cancel()
        if case .refresh = activeLoad?.kind, state.isRefreshing {
            state.isRefreshing = false
        }
        loadTask = nil
        activeLoad = nil
    }

    private func pageLoad(for kind: LoadKind) -> PageLoad {
        let page = if case .nextPage = kind { store.nextPage } else { Constants.API.firstPage }
        return PageLoad(kind: kind, page: page, pageSize: store.pageSize)
    }

    private func finishLoading(_ load: PageLoad, with result: Result<NewsPage, any Error>) {
        loadTask = nil
        activeLoad = nil
        switch result {
        case .success(let page):
            apply(page, for: load.kind)
        case .failure(let error):
            handleFailure(error, of: load)
        }
    }

    private func apply(_ page: NewsPage, for kind: LoadKind) {
        switch kind {
        case .firstPage, .refresh:
            applyFirstPage(page)
        case .nextPage:
            applyNextPage(page)
        }
    }

    private func applyFirstPage(_ page: NewsPage) {
        store.replace(with: page)
        state = NewsFeedViewState(
            itemIDs: store.orderedIDs,
            phase: store.isEmpty ? .empty : .content,
            pagingFooter: pagingFooterForStore,
            isRefreshing: false,
            contentRevision: state.contentRevision + 1
        )
    }

    private func applyNextPage(_ page: NewsPage) {
        store.append(page)
        publishStoreItems()
        if store.lastAppendedCount == 0, store.hasMore {
            startLoading(.nextPage)
        }
    }

    private func publishStoreItems() {
        var newState = state
        newState.itemIDs = store.orderedIDs
        newState.pagingFooter = pagingFooterForStore
        state = newState
    }

    private var pagingFooterForStore: NewsFeedViewState.PagingFooter {
        store.hasMore ? .loading : .hidden
    }

    private func handleFailure(_ error: any Error, of load: PageLoad) {
        log(error, of: load)
        let message = errorMessages.message(for: error)
        switch load.kind {
        case .firstPage:
            state.phase = .failed(message: message)
        case .refresh(let mode):
            handleRefreshFailure(message, mode: mode)
        case .nextPage:
            state.pagingFooter = .failed(message: message)
        }
    }

    private func handleRefreshFailure(_ message: String, mode: RefreshMode) {
        state.isRefreshing = false
        messageSubject.send(message)
        guard case .interruptingPaging = mode, canLoadNextPage else { return }
        startLoading(.nextPage)
    }

    private func log(_ error: any Error, of load: PageLoad) {
        let prefix = Log.pageLoadFailed(kind: String(describing: load.kind), page: load.page)
        Self.logger.error("\(prefix, privacy: .public) \(error)")
    }
}
