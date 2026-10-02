import UIKit

@MainActor
protocol NewsFeedViewComponentsMaking {
    func makeContentRenderer(for collectionView: UICollectionView) -> any NewsFeedContentRendering
    func makeInteractions(
        locator: any NewsFeedItemLocating,
        presenter: UIViewController
    ) -> any NewsFeedInteractionHandling
    func makeRefreshController() -> any NewsFeedRefreshControlling
}

extension NewsFeedViewController {
    struct Dependencies {
        let layoutProvider: any NewsFeedLayoutProviding
        let components: any NewsFeedViewComponentsMaking
        let notificationCenter: NotificationCenter
    }
}
