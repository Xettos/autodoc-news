import Foundation
import os
import Testing
@testable import AutodocNews

@MainActor
@Suite("NewsDetailViewModel", .timeLimit(.minutes(1)))
struct NewsDetailViewModelTests {
    private let item = NewsItem.fixture(id: 7)
    private let repository = StubNewsRepository()
    private let errorMessageMapper = RecordingErrorMessageMapper()
    private let viewModel: NewsDetailViewModel
    private let bodyStates: PublisherRecorder<NewsDetailBodyState>

    init() {
        viewModel = NewsDetailViewModel(
            item: item,
            repository: repository,
            dateFormatter: StubNewsDateFormatter(),
            errorMessageMapper: errorMessageMapper
        )
        bodyStates = PublisherRecorder(viewModel.bodyStatePublisher)
    }

    @Test("header is available immediately from the feed item")
    func headerFromItem() {
        #expect(viewModel.header.title == item.title)
        #expect(viewModel.header.imageURL == item.imageURL)
        #expect(viewModel.header.webURL == item.webURL)
    }

    @Test("body starts in the loading state")
    func initialBodyStateIsLoading() {
        #expect(bodyStates.latest == .loading)
    }

    @Test("load fetches the article by path and shows it with the header's hero image")
    func loadSucceeds() async throws {
        repository.articles.enqueue(.success(.fixture(item: item, html: "<p>Статья</p>")), for: item.path)

        viewModel.load()
        let state = try await bodyStates.waitForLatest { $0 != .loading }

        #expect(state == loaded("<p>Статья</p>"))
        #expect(repository.articles.calls == [item.path])
    }

    @Test("failure shows the message of the injected error mapper")
    func loadFails() async throws {
        repository.articles.enqueue(.failure(NetworkError.timedOut), for: item.path)

        viewModel.load()
        let state = try await bodyStates.waitForLatest { $0 != .loading }

        #expect(state == .failed(message: RecordingErrorMessageMapper.message))
        #expect(errorMessageMapper.mappedErrors == [String(describing: NetworkError.timedOut)])
    }

    @Test("CancellationError that did not come from task cancellation is a retryable failure")
    func spuriousCancellationFails() async throws {
        viewModel.load()
        await repository.articles.waitForPendingCall(for: item.path)
        repository.articles.resolvePendingCall(for: item.path, with: .failure(CancellationError()))

        let state = try await bodyStates.waitForLatest { $0 != .loading }

        #expect(state == .failed(message: RecordingErrorMessageMapper.message))
    }

    @Test("retry after a spurious cancellation loads the article")
    func retryAfterSpuriousCancellation() async throws {
        repository.articles.enqueue(.failure(CancellationError()), for: item.path)
        repository.articles.enqueue(.success(.fixture(item: item)), for: item.path)
        viewModel.load()
        try await bodyStates.waitForLatest { $0 != .loading }

        viewModel.retry()
        let state = try await bodyStates.waitForLatest { $0 != .loading }

        #expect(state == loaded("<p>Текст статьи</p>"))
        #expect(repository.articles.calls == [item.path, item.path])
    }

    @Test("retry after a failure shows loading and then the article")
    func retryAfterFailure() async throws {
        repository.articles.enqueue(.failure(NetworkError.offline), for: item.path)
        repository.articles.enqueue(.success(.fixture(item: item)), for: item.path)
        viewModel.load()
        try await bodyStates.waitForLatest { $0 != .loading }

        viewModel.retry()
        #expect(bodyStates.latest == .loading)
        let state = try await bodyStates.waitForLatest { $0 != .loading }

        #expect(state == loaded("<p>Текст статьи</p>"))
        #expect(repository.articles.calls == [item.path, item.path])
    }

    @Test("load while a request is in flight or after success does not refetch")
    func loadIsIdempotent() async throws {
        viewModel.load()
        await repository.articles.waitForPendingCall(for: item.path)
        viewModel.load()
        viewModel.retry()
        repository.articles.resolvePendingCall(for: item.path, with: .success(.fixture(item: item)))
        try await bodyStates.waitForLatest { $0 != .loading }

        viewModel.load()

        #expect(repository.articles.calls == [item.path])
        #expect(bodyStates.latest == loaded("<p>Текст статьи</p>"))
    }

    private func loaded(_ html: String) -> NewsDetailBodyState {
        .loaded(ArticleContent(fragment: html, heroImageURL: item.imageURL))
    }
}

@MainActor
@Suite("NewsDetailViewModel header mapping")
struct NewsDetailHeaderMappingTests {
    private let repository = StubNewsRepository()

    @Test("blank category and summary become nil, the date goes through the injected formatter")
    func mapsBlankFieldsAndDate() {
        let item = makeItem(summary: "  \n", category: "", publishedAt: Date(timeIntervalSince1970: 0))

        let header = makeHeader(for: item, formattedDate: "17 августа 2026")

        #expect(header.category == nil)
        #expect(header.summary == nil)
        #expect(header.publishedDateText == "17 августа 2026")
    }

    @Test("category and summary are trimmed, a missing date stays nil")
    func trimsTextAndKeepsMissingDate() {
        let item = makeItem(summary: " Анонс \n", category: "\tНовости ", publishedAt: nil)

        let header = makeHeader(for: item, formattedDate: "DATE")

        #expect(header.category == "Новости")
        #expect(header.summary == "Анонс")
        #expect(header.publishedDateText == nil)
    }

    private func makeHeader(for item: NewsItem, formattedDate: String) -> NewsDetailHeaderViewData {
        NewsDetailViewModel(
            item: item,
            repository: repository,
            dateFormatter: StubNewsDateFormatter(output: formattedDate),
            errorMessageMapper: RecordingErrorMessageMapper()
        ).header
    }

    private func makeItem(summary: String, category: String, publishedAt: Date?) -> NewsItem {
        NewsItem(
            id: 1, title: "Заголовок", summary: summary, publishedAt: publishedAt, path: "a/b",
            webURL: nil, imageURL: nil, category: category
        )
    }
}

private final class RecordingErrorMessageMapper: ErrorMessageMapping {
    static let message = "Сообщение маппера"

    private let errors = OSAllocatedUnfairLock(initialState: [String]())

    var mappedErrors: [String] {
        errors.withLock { $0 }
    }

    func message(for error: any Error) -> String {
        errors.withLock { $0.append(String(describing: error)) }
        return Self.message
    }
}
