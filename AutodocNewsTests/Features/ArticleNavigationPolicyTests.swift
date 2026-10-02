import Foundation
import Testing
@testable import AutodocNews

@Suite("ArticleNavigationPolicy")
struct ArticleNavigationPolicyTests {
    static let documentURL = URL(string: "https://www.autodoc.ru")
    static let externalURL = URL(string: "https://evil.example.com/page")
    private let policy = ArticleNavigationPolicy(documentURL: documentURL)

    @Test("the article's own document load is allowed while it is awaited", arguments: [
        ArticleNavigationPolicyTests.documentURL,
        URL(string: "https://www.autodoc.ru/"),
        URL(string: "about:blank"),
        nil,
    ])
    func allowsAwaitedDocument(url: URL?) {
        let request = makeRequest(.other, url: url, isAwaitingDocument: true)

        #expect(policy.decision(for: request) == .allow)
    }

    @Test("a main-frame load after the document is cancelled without opening it", arguments: [
        ArticleNavigationPolicyTests.externalURL,
        ArticleNavigationPolicyTests.documentURL,
    ])
    func cancelsMainFrameRedirect(url: URL?) {
        let request = makeRequest(.other, url: url, isAwaitingDocument: false)

        #expect(policy.decision(for: request) == .cancel)
    }

    @Test("a foreign main-frame load is cancelled even while the document is awaited")
    func cancelsForeignLoadWhileAwaiting() {
        let request = makeRequest(.other, url: Self.externalURL, isAwaitingDocument: true)

        #expect(policy.decision(for: request) == .cancel)
    }

    @Test("embedded frames load freely")
    func allowsSubframes() {
        let request = makeRequest(.other, url: Self.externalURL, isMainFrame: false)

        #expect(policy.decision(for: request) == .allow)
    }

    @Test("an activated link is cancelled and opened externally")
    func opensActivatedLinks() throws {
        let url = try #require(Self.externalURL)
        let request = makeRequest(.linkActivated, url: url)

        #expect(policy.decision(for: request) == .openExternally(url))
    }

    @Test("an activated link without a URL is just cancelled")
    func cancelsLinkWithoutURL() {
        #expect(policy.decision(for: makeRequest(.linkActivated, url: nil)) == .cancel)
    }

    @Test("forms, history and reloads are cancelled", arguments: [
        ArticleNavigationRequest.Kind.formSubmission,
        .backForward,
        .reload,
    ])
    func cancelsOtherKinds(kind: ArticleNavigationRequest.Kind) {
        let request = makeRequest(kind, url: Self.documentURL, isAwaitingDocument: true)

        #expect(policy.decision(for: request) == .cancel)
    }

    private func makeRequest(
        _ kind: ArticleNavigationRequest.Kind,
        url: URL?,
        isMainFrame: Bool = true,
        isAwaitingDocument: Bool = false
    ) -> ArticleNavigationRequest {
        ArticleNavigationRequest(kind: kind, url: url, isMainFrame: isMainFrame, isAwaitingDocument: isAwaitingDocument)
    }
}

@Suite("ArticleLinkRoute")
struct ArticleLinkRouteTests {
    @Test("links are routed by scheme", arguments: [
        ("https://autodoc.ru/news", ArticleLinkRoute.safari),
        ("HTTP://autodoc.ru", .safari),
        ("mailto:info@autodoc.ru", .system),
        ("tel:+78001234567", .system),
        ("javascript:alert(1)", .ignored),
        ("file:///etc/hosts", .ignored),
    ])
    func routesByScheme(address: String, expected: ArticleLinkRoute) throws {
        let url = try #require(URL(string: address))

        #expect(ArticleLinkRoute(url: url) == expected)
    }
}

@Suite("HeroImageRequestPolicy")
struct HeroImageRequestPolicyTests {
    private let policy = HeroImageRequestPolicy()
    private let url: URL

    init() throws {
        url = try #require(URL(string: "https://file.autodoc.ru/hero.jpg"))
    }

    @Test("the first request is always made")
    func firstRequest() {
        #expect(policy.shouldReplace(current: nil, displayedPixelSize: nil, with: request(width: 100)))
    }

    @Test("a larger size not covered by the current request or the image is re-requested")
    func largerSizeIsRequested() {
        #expect(policy.shouldReplace(current: request(width: 100), displayedPixelSize: nil, with: request(width: 400)))
    }

    @Test("a smaller or equal size keeps the current request")
    func smallerSizeIsKept() {
        #expect(!policy.shouldReplace(current: request(width: 400), displayedPixelSize: nil, with: request(width: 100)))
        #expect(!policy.shouldReplace(current: request(width: 400), displayedPixelSize: nil, with: request(width: 400)))
    }

    @Test("a displayed image that already covers the new size keeps the current request")
    func displayedImageCovers() {
        let displayed = ImageRequest.PixelSize(width: 4_000, height: 4_000)

        #expect(!policy.shouldReplace(current: request(width: 100), displayedPixelSize: displayed, with: request(width: 400)))
    }

    private func request(width: CGFloat) -> ImageRequest {
        ImageRequest(url: url, targetSize: CGSize(width: width, height: width / 2), scale: 1)
    }
}

@Suite("ArticleWebView height")
struct ArticleWebViewHeightTests {
    @Test("reported height is clamped to 0...max", arguments: [
        (-10.0, 0.0),
        (250.0, 250.0),
        (1e9, Double(Constants.Detail.Web.maxContentHeight)),
    ])
    func clampsHeight(reported: Double, expected: Double) {
        #expect(ArticleWebView.clampedHeight(CGFloat(reported)) == CGFloat(expected))
    }

    @Test("non-numeric and non-finite message bodies are rejected")
    func rejectsInvalidBodies() {
        #expect(ArticleWebView.height(from: "100") == nil)
        #expect(ArticleWebView.height(from: NSNumber(value: Double.nan)) == nil)
        #expect(ArticleWebView.height(from: NSNumber(value: Double.infinity)) == nil)
        #expect(ArticleWebView.height(from: NSNumber(value: 42)) == 42)
    }

    @Test("changes below the threshold are ignored")
    func ignoresTinyChanges() {
        let threshold = Constants.Detail.Web.heightChangeThreshold

        #expect(!ArticleWebView.isSignificantHeightChange(from: 100, to: 100 + threshold / 2))
        #expect(ArticleWebView.isSignificantHeightChange(from: 100, to: 100 + threshold))
    }
}
