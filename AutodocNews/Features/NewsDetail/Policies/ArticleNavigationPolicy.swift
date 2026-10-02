import Foundation

struct ArticleNavigationRequest: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case linkActivated
        case formSubmission
        case backForward
        case reload
        case other
    }

    let kind: Kind
    let url: URL?
    let isMainFrame: Bool
    let isAwaitingDocument: Bool
}

enum ArticleNavigationDecision: Equatable, Sendable {
    case allow
    case cancel
    case openExternally(URL)
}

protocol ArticleNavigationDeciding: Sendable {
    func decision(for request: ArticleNavigationRequest) -> ArticleNavigationDecision
}

struct ArticleNavigationPolicy: ArticleNavigationDeciding {
    private let documentURL: URL?

    init(documentURL: URL?) {
        self.documentURL = documentURL
    }

    func decision(for request: ArticleNavigationRequest) -> ArticleNavigationDecision {
        switch request.kind {
        case .linkActivated:
            return linkDecision(for: request.url)
        case .other:
            return isAllowedLoad(request) ? .allow : .cancel
        case .formSubmission, .backForward, .reload:
            return .cancel
        }
    }

    private func linkDecision(for url: URL?) -> ArticleNavigationDecision {
        guard let url else { return .cancel }
        return .openExternally(url)
    }

    private func isAllowedLoad(_ request: ArticleNavigationRequest) -> Bool {
        guard request.isMainFrame else { return true }
        return request.isAwaitingDocument && isDocumentURL(request.url)
    }

    private func isDocumentURL(_ url: URL?) -> Bool {
        guard let url else { return true }
        guard url.absoluteString != Constants.Detail.Web.blankDocumentAddress else { return true }
        return url.scheme == documentURL?.scheme && url.host() == documentURL?.host()
    }
}
