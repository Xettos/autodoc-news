import WebKit

extension ArticleNavigationRequest {
    @MainActor
    init(_ action: WKNavigationAction, isAwaitingDocument: Bool) {
        self.init(
            kind: Kind(action.navigationType),
            url: action.request.url,
            isMainFrame: action.targetFrame?.isMainFrame ?? true,
            isAwaitingDocument: isAwaitingDocument
        )
    }
}

extension ArticleNavigationRequest.Kind {
    init(_ type: WKNavigationType) {
        switch type {
        case .linkActivated: self = .linkActivated
        case .formSubmitted, .formResubmitted: self = .formSubmission
        case .backForward: self = .backForward
        case .reload: self = .reload
        case .other: self = .other
        @unknown default: self = .other
        }
    }
}

extension ArticleNavigationDecision {
    var webKitPolicy: WKNavigationActionPolicy {
        self == .allow ? .allow : .cancel
    }
}
