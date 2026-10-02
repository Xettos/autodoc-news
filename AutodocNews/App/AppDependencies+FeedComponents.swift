import UIKit

@MainActor
struct NewsFeedViewComponentsFactory: NewsFeedViewComponentsMaking {
    struct Services {
        let imageLoader: any ImageLoading
        let snapshotBuilder: any NewsFeedSnapshotBuilding
        let imageRequestFactory: any NewsFeedImageRequestMaking
        let imagePrefetcher: any NewsFeedImagePrefetching
        let itemMenuProvider: any NewsFeedItemMenuProviding
    }

    private let viewModel: any NewsFeedViewModelProtocol
    private let services: Services

    init(viewModel: any NewsFeedViewModelProtocol, services: Services) {
        self.viewModel = viewModel
        self.services = services
    }

    func makeContentRenderer(for collectionView: UICollectionView) -> any NewsFeedContentRendering {
        let dependencies = NewsFeedContentRenderer.Dependencies(
            viewModel: viewModel,
            imageLoader: services.imageLoader,
            snapshotBuilder: services.snapshotBuilder,
            cardContentProvider: makeCardContentProvider(),
            imagePrefetcher: services.imagePrefetcher
        )
        return NewsFeedContentRenderer(collectionView: collectionView, dependencies: dependencies)
    }

    func makeInteractions(
        locator: any NewsFeedItemLocating,
        presenter: UIViewController
    ) -> any NewsFeedInteractionHandling {
        let dependencies = NewsFeedCollectionInteractions.Dependencies(
            viewModel: viewModel,
            locator: locator,
            cardContentProvider: makeCardContentProvider(),
            imagePrefetcher: services.imagePrefetcher,
            itemMenuProvider: services.itemMenuProvider
        )
        return NewsFeedCollectionInteractions(presenter: presenter, dependencies: dependencies)
    }

    func makeRefreshController() -> any NewsFeedRefreshControlling {
        NewsFeedRefreshController(viewModel: viewModel)
    }

    private func makeCardContentProvider() -> any NewsFeedCardContentProviding {
        NewsFeedCardContentProvider(viewModel: viewModel, imageRequestFactory: services.imageRequestFactory)
    }
}
