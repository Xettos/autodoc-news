import UIKit

@MainActor
protocol ArticleBodyDisplaying: UIView {
    var onRetry: (() -> Void)? { get set }
    var onOpenLink: ((URL) -> Void)? { get set }

    func showLoading()
    func showError(message: String)
    func showArticle(_ content: ArticleContent)
}

@MainActor
final class ArticleBodyView: UIView {
    var onRetry: (() -> Void)? {
        get { errorView.onRetry }
        set { errorView.onRetry = newValue }
    }

    var onOpenLink: ((URL) -> Void)? {
        get { webView.onOpenLink }
        set { webView.onOpenLink = newValue }
    }

    private let skeletonView = ArticleSkeletonView()
    private let errorView = ArticleErrorView()
    private let webView: ArticleWebView

    init(articleRenderer: any ArticleHTMLRendering, navigationPolicy: any ArticleNavigationDeciding) {
        webView = ArticleWebView(renderer: articleRenderer, navigationPolicy: navigationPolicy)
        super.init(frame: .zero)
        layoutStateViews()
        removeSkeletonWhenContentReady()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private var stateViews: [UIView] {
        [skeletonView, errorView, webView]
    }

    private func layoutStateViews() {
        let stackView = UIStackView(arrangedSubviews: stateViews)
        stackView.axis = .vertical
        addSubviews(stackView)
        stackView.pinEdges(to: self)
    }

    private func removeSkeletonWhenContentReady() {
        webView.onContentReady = { [weak skeletonView] in
            skeletonView?.removeFromSuperview()
        }
    }

    private func showOnly(_ visibleViews: [UIView]) {
        for view in stateViews {
            view.isHidden = !visibleViews.contains(view)
        }
    }
}

extension ArticleBodyView: ArticleBodyDisplaying {
    func showLoading() {
        showOnly([skeletonView])
    }

    func showError(message: String) {
        errorView.configure(message: message)
        showOnly([errorView])
    }

    func showArticle(_ content: ArticleContent) {
        webView.load(content)
        showOnly(webView.isContentReady ? [webView] : [skeletonView, webView])
    }
}
