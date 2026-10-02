import os
@testable import AutodocNews

@MainActor
struct NewsFeedTestContext<Repository: ScriptedNewsRepository> {
    static var pageSize: Int { Constants.API.pageSize }

    let repository: Repository
    let pagingTrigger: RecordingPagingTrigger
    let viewModel: NewsFeedViewModel
    let states: PublisherRecorder<NewsFeedViewState>

    init(repository: Repository, pagingDecision: RecordingPagingTrigger.Decision = .production) {
        self.repository = repository
        pagingTrigger = RecordingPagingTrigger(decision: pagingDecision)
        let dependencies = NewsFeedViewModel.Dependencies(
            repository: repository,
            viewDataMapper: NewsCardViewDataMapper(dateFormatter: StubNewsDateFormatter()),
            pagingTrigger: pagingTrigger,
            errorMessages: ErrorMessageMapper()
        )
        viewModel = NewsFeedViewModel(dependencies: dependencies, pageSize: Self.pageSize)
        states = PublisherRecorder(viewModel.statePublisher)
    }

    @discardableResult
    func loadFirstPage(ids: ClosedRange<Int>, totalCount: Int) async throws -> NewsFeedViewState {
        repository.stubPage(Constants.API.firstPage, ids: ids, totalCount: totalCount)
        viewModel.start()
        return try await states.waitForLatest { $0.phase == .content }
    }
}

protocol ScriptedNewsRepository: NewsRepository {
    var news: ScriptedResponder<Int, NewsPage> { get }
}

extension ScriptedNewsRepository {
    func stubPage(_ page: Int, ids: ClosedRange<Int>, totalCount: Int) {
        news.enqueue(.success(.fixture(ids: Array(ids), totalCount: totalCount)), for: page)
    }

    func stubPage(_ page: Int, failingWith error: any Error) {
        news.enqueue(.failure(error), for: page)
    }

    @discardableResult
    func resolvePage(_ page: Int, ids: ClosedRange<Int>, totalCount: Int) -> Bool {
        news.resolvePendingCall(for: page, with: .success(.fixture(ids: Array(ids), totalCount: totalCount)))
    }
}

extension StubNewsRepository: ScriptedNewsRepository {}

final class NonCooperativeNewsRepository: ScriptedNewsRepository {
    let news = ScriptedResponder<Int, NewsPage>()
    let deliveredPages = EventLog<Int>()

    func fetchNews(page: Int, pageSize: Int) async throws -> NewsPage {
        let result = await Task { [news] in try await news.respond(to: page) }.result
        deliveredPages.record(page)
        return try result.get()
    }

    func fetchArticle(path: String) async throws -> NewsArticle {
        throw TestError.unexpected
    }
}

final class RecordingPagingTrigger: NewsFeedPagingTriggering {
    enum Decision: Sendable {
        case production
        case always
        case never
    }

    struct Question: Equatable, Sendable {
        let visibleIndex: Int
        let itemCount: Int
    }

    private let decision: Decision
    private let recordedQuestions = OSAllocatedUnfairLock(initialState: [Question]())
    private let productionTrigger = NewsFeedPagingTrigger(threshold: Constants.Feed.Pagination.nextPageThreshold)

    init(decision: Decision) {
        self.decision = decision
    }

    var questions: [Question] {
        recordedQuestions.withLock { $0 }
    }

    func shouldLoadNextPage(visibleIndex: Int, itemCount: Int) -> Bool {
        recordedQuestions.withLock { $0.append(Question(visibleIndex: visibleIndex, itemCount: itemCount)) }
        switch decision {
        case .production:
            return productionTrigger.shouldLoadNextPage(visibleIndex: visibleIndex, itemCount: itemCount)
        case .always:
            return true
        case .never:
            return false
        }
    }
}
