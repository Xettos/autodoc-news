import UIKit

@MainActor
protocol NewsFeedItemMenuProviding {
    func menu(for item: NewsItem, presenter: UIViewController, anchor: @escaping () -> UIView?) -> UIMenu?
}

struct NewsFeedItemMenuProvider: NewsFeedItemMenuProviding {
    private let sharePresenter: any SharePresenting
    private let urlOpener: any URLOpening

    init(sharePresenter: any SharePresenting, urlOpener: any URLOpening) {
        self.sharePresenter = sharePresenter
        self.urlOpener = urlOpener
    }

    func menu(for item: NewsItem, presenter: UIViewController, anchor: @escaping () -> UIView?) -> UIMenu? {
        let handlers = NewsItemMenu.Handlers(
            share: { [weak presenter, sharePresenter] url in
                guard let presenter, let sourceView = anchor() else { return }
                sharePresenter.presentShareSheet(for: url, anchor: .view(sourceView), from: presenter)
            },
            openInBrowser: { [urlOpener] url in urlOpener.open(url: url) }
        )
        return NewsItemMenu.make(for: item, handlers: handlers)
    }
}
