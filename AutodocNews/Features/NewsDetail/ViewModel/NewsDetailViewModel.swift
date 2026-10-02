import Combine
import Foundation
import os

@MainActor
final class NewsDetailViewModel: NewsDetailViewModelProtocol {
    private static let logger = Logger(
        subsystem: Constants.App.Log.subsystem,
        category: Constants.Detail.Log.viewModelCategory
    )

    let header: NewsDetailHeaderViewData
    @Published private(set) var bodyState: NewsDetailBodyState = .loading

    private let articlePath: String
    private let repository: any NewsRepository
    private let errorMessageMapper: any ErrorMessageMapping
    private var loadTask: Task<Void, Never>?

    var bodyStatePublisher: AnyPublisher<NewsDetailBodyState, Never> {
        $bodyState.eraseToAnyPublisher()
    }

    init(
        item: NewsItem,
        repository: any NewsRepository,
        dateFormatter: any NewsDateFormatting,
        errorMessageMapper: any ErrorMessageMapping
    ) {
        self.header = Self.makeHeader(from: item, dateFormatter: dateFormatter)
        self.articlePath = item.path
        self.repository = repository
        self.errorMessageMapper = errorMessageMapper
    }

    deinit {
        loadTask?.cancel()
    }

    func load() {
        guard !isLoading, !bodyState.isLoaded else { return }
        startLoading()
    }

    func retry() {
        guard !isLoading, bodyState.isFailed else { return }
        bodyState = .loading
        startLoading()
    }

    private static func makeHeader(
        from item: NewsItem,
        dateFormatter: any NewsDateFormatting
    ) -> NewsDetailHeaderViewData {
        NewsDetailHeaderViewData(
            title: item.title,
            category: item.category.trimmedNonEmpty,
            publishedDateText: item.publishedAt.map(dateFormatter.string(from:)),
            summary: item.summary.trimmedNonEmpty,
            imageURL: item.imageURL,
            webURL: item.webURL
        )
    }

    private var isLoading: Bool {
        loadTask != nil
    }

    private func startLoading() {
        loadTask = Task { [weak self, repository, articlePath] in
            let result = await Result<NewsArticle, any Error> {
                try await repository.fetchArticle(path: articlePath)
            }
            guard !Task.isCancelled else { return }
            self?.finishLoading(with: result)
        }
    }

    private func finishLoading(with result: Result<NewsArticle, any Error>) {
        loadTask = nil
        switch result {
        case .success(let article):
            bodyState = .loaded(makeContent(from: article))
        case .failure(let error):
            handleFailure(error)
        }
    }

    private func makeContent(from article: NewsArticle) -> ArticleContent {
        ArticleContent(fragment: article.html, heroImageURL: header.imageURL)
    }

    private func handleFailure(_ error: any Error) {
        let path = articlePath
        Self.logger.error(
            "\(Constants.Detail.Log.articleLoadFailed, privacy: .public) \(path, privacy: .public): \(error)"
        )
        bodyState = .failed(message: errorMessageMapper.message(for: error))
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
