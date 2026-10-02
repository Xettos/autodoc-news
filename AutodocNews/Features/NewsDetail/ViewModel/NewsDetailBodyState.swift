enum NewsDetailBodyState: Equatable, Sendable {
    case loading
    case loaded(ArticleContent)
    case failed(message: String)
}

extension NewsDetailBodyState {
    var isLoaded: Bool {
        guard case .loaded = self else { return false }
        return true
    }

    var isFailed: Bool {
        guard case .failed = self else { return false }
        return true
    }
}
