import UIKit

@MainActor
enum NewsItemMenu {
    struct Handlers {
        let share: (URL) -> Void
        let openInBrowser: (URL) -> Void
    }

    private typealias Text = Constants.Feed.Text

    static func make(for item: NewsItem, handlers: Handlers) -> UIMenu? {
        guard let url = item.webURL else { return nil }
        return UIMenu(children: [
            shareAction(for: url, onShare: handlers.share),
            openInSafariAction(for: url, onOpen: handlers.openInBrowser),
            copyLinkAction(for: url)
        ])
    }

    private static func shareAction(for url: URL, onShare: @escaping (URL) -> Void) -> UIAction {
        UIAction(title: Text.share, image: UIImage(systemName: Text.Symbol.share)) { _ in
            onShare(url)
        }
    }

    private static func openInSafariAction(for url: URL, onOpen: @escaping (URL) -> Void) -> UIAction {
        UIAction(title: Text.openInSafari, image: UIImage(systemName: Text.Symbol.openInSafari)) { _ in
            onOpen(url)
        }
    }

    private static func copyLinkAction(for url: URL) -> UIAction {
        UIAction(title: Text.copyLink, image: UIImage(systemName: Text.Symbol.copyLink)) { _ in
            UIPasteboard.general.url = url
        }
    }
}
