import os
import UIKit
import WebKit

@MainActor
final class ArticleWebView: UIView {
    private typealias Web = Constants.Detail.Web

    private static let logger = Logger(
        subsystem: Constants.App.Log.subsystem,
        category: Constants.Detail.Log.webViewCategory
    )

    var onOpenLink: ((URL) -> Void)?
    var onContentReady: (() -> Void)?

    private let renderer: any ArticleHTMLRendering
    private let navigationPolicy: any ArticleNavigationDeciding
    private let userContentController: WKUserContentController
    private let webView: WKWebView
    private var contentHeight: CGFloat = 0
    private var loadedContent: ArticleContent?
    private var loadedHTML: String?
    private var isAwaitingFirstMeasurement = false
    private var isAwaitingDocument = false
    private var renderTask: Task<Void, Never>?

    init(renderer: any ArticleHTMLRendering, navigationPolicy: any ArticleNavigationDeciding) {
        self.renderer = renderer
        self.navigationPolicy = navigationPolicy
        let contentController = Self.makeUserContentController()
        userContentController = contentController
        webView = WKWebView(frame: .zero, configuration: Self.makeConfiguration(userContentController: contentController))
        super.init(frame: .zero)
        registerHeightMessageHandler()
        configureWebView()
        configureInnerScrollView()
        layoutWebView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        renderTask?.cancel()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: max(contentHeight, Web.minimumRenderableHeight))
    }

    var isContentReady: Bool {
        loadedContent != nil && !isAwaitingFirstMeasurement
    }

    func load(_ content: ArticleContent) {
        guard content != loadedContent else { return }
        loadedContent = content
        hideUntilMeasured()
        render(content)
    }

    nonisolated static func height(from body: Any) -> CGFloat? {
        guard let number = body as? NSNumber else { return nil }
        let value = CGFloat(number.doubleValue)
        return value.isFinite ? value : nil
    }

    nonisolated static func clampedHeight(_ height: CGFloat) -> CGFloat {
        min(max(height, 0), Web.maxContentHeight)
    }

    nonisolated static func isSignificantHeightChange(from oldHeight: CGFloat, to newHeight: CGFloat) -> Bool {
        abs(newHeight - oldHeight) >= Web.heightChangeThreshold
    }

    private func hideUntilMeasured() {
        isAwaitingFirstMeasurement = true
        webView.alpha = 0
    }

    private func render(_ content: ArticleContent) {
        let style = ArticleHTMLStyle(accent: Palette.accent)
        renderTask?.cancel()
        renderTask = Task { [weak self, renderer] in
            let html = await renderer.renderDocument(for: content, style: style)
            guard !Task.isCancelled else { return }
            self?.finishRendering(html)
        }
    }

    private func finishRendering(_ html: String) {
        renderTask = nil
        display(html)
    }

    private func display(_ html: String) {
        loadedHTML = html
        isAwaitingDocument = true
        webView.loadHTMLString(html, baseURL: Web.baseURL)
    }

    private func updateContentHeight(_ reportedHeight: CGFloat) {
        let height = Self.clampedHeight(reportedHeight)
        guard Self.isSignificantHeightChange(from: contentHeight, to: height) else { return }
        contentHeight = height
        invalidateIntrinsicContentSize()
    }

    private func revealIfNeeded() {
        guard isAwaitingFirstMeasurement else { return }
        isAwaitingFirstMeasurement = false
        animateReveal()
        onContentReady?()
    }

    private func animateReveal() {
        UIView.animate(
            withDuration: Constants.Detail.Animation.revealDuration,
            delay: 0,
            options: [.allowUserInteraction]
        ) { [webView] in
            webView.alpha = 1
        }
    }

    private func registerHeightMessageHandler() {
        userContentController.add(
            WeakScriptMessageHandler(target: self),
            contentWorld: .defaultClient,
            name: Web.heightMessageName
        )
    }

    private func configureWebView() {
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.allowsLinkPreview = false
        webView.alpha = 0
        #if DEBUG
        webView.isInspectable = true
        #endif
    }

    private func configureInnerScrollView() {
        let scrollView = webView.scrollView
        scrollView.isScrollEnabled = false
        scrollView.scrollsToTop = false
        scrollView.bounces = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
    }

    private func layoutWebView() {
        addSubviews(webView)
        webView.pinEdges(to: self)
    }

    private static func makeUserContentController() -> WKUserContentController {
        let controller = WKUserContentController()
        controller.addUserScript(makeHeightObserverScript())
        return controller
    }

    private static func makeConfiguration(userContentController: WKUserContentController) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = []
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.userContentController = userContentController
        return configuration
    }

    private static func makeHeightObserverScript() -> WKUserScript {
        WKUserScript(
            source: Web.heightObserverScript(handlerName: Web.heightMessageName),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true,
            in: .defaultClient
        )
    }
}

extension ArticleWebView: WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Web.heightMessageName, let height = Self.height(from: message.body) else { return }
        updateContentHeight(height)
        revealIfNeeded()
    }
}

extension ArticleWebView: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        let request = ArticleNavigationRequest(navigationAction, isAwaitingDocument: isAwaitingDocument)
        let decision = navigationPolicy.decision(for: request)
        decisionHandler(decision.webKitPolicy)
        apply(decision, to: request)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        handleNavigationFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        handleNavigationFailure(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard let loadedHTML else { return }
        display(loadedHTML)
    }

    private func apply(_ decision: ArticleNavigationDecision, to request: ArticleNavigationRequest) {
        switch decision {
        case .allow where request.isMainFrame:
            isAwaitingDocument = false
        case .openExternally(let url):
            onOpenLink?(url)
        case .allow, .cancel:
            break
        }
    }

    private func handleNavigationFailure(_ error: any Error) {
        guard (error as? URLError)?.code != .cancelled else { return }
        Self.logger.error("\(Constants.Detail.Log.articleRenderFailed, privacy: .public): \(error)")
        revealIfNeeded()
    }
}
