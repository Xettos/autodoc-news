import UIKit

@MainActor
protocol NewsFeedInteractionHandling:
    UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, UICollectionViewDragDelegate {}

@MainActor
final class NewsFeedCollectionInteractions: NSObject, NewsFeedInteractionHandling {
    struct Dependencies {
        let viewModel: any NewsFeedViewModelProtocol
        let locator: any NewsFeedItemLocating
        let cardContentProvider: any NewsFeedCardContentProviding
        let imagePrefetcher: any NewsFeedImagePrefetching
        let itemMenuProvider: any NewsFeedItemMenuProviding
    }

    private let dependencies: Dependencies
    private weak var presenter: UIViewController?

    init(presenter: UIViewController, dependencies: Dependencies) {
        self.presenter = presenter
        self.dependencies = dependencies
    }

    private var viewModel: any NewsFeedViewModelProtocol { dependencies.viewModel }

    private func newsID(at indexPath: IndexPath) -> NewsItem.ID? {
        dependencies.locator.newsID(at: indexPath)
    }

    private func newsItem(at indexPath: IndexPath) -> NewsItem? {
        newsID(at: indexPath).flatMap(viewModel.item(with:))
    }

    private func shareAnchor(for itemID: NewsItem.ID) -> UIView? {
        dependencies.locator.cell(for: itemID) ?? presenter?.view
    }

    private func loadMoreIfNeeded(near indexPaths: [IndexPath]) {
        guard let farthestIndex = indexPaths.compactMap(dependencies.locator.feedIndex(for:)).max() else { return }
        viewModel.loadMoreIfNeeded(visibleIndex: farthestIndex)
    }

    private func imagePrefetch(at indexPath: IndexPath) -> NewsImagePrefetch? {
        guard
            let itemID = newsID(at: indexPath),
            let content = dependencies.cardContentProvider.cardContent(
                for: itemID,
                in: dependencies.locator.imageSlot(at: indexPath)
            ),
            let request = content.imageRequest
        else { return nil }
        return NewsImagePrefetch(itemID: itemID, request: request)
    }

    private func contextMenu(for item: NewsItem) -> UIContextMenuConfiguration? {
        guard let presenter else { return nil }
        let menu = dependencies.itemMenuProvider.menu(for: item, presenter: presenter) { [weak self] in
            self?.shareAnchor(for: item.id)
        }
        return menu.map { menu in UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in menu } }
    }
}

extension NewsFeedCollectionInteractions {
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        newsID(at: indexPath) != nil
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let itemID = newsID(at: indexPath) else { return }
        viewModel.selectItem(id: itemID)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        loadMoreIfNeeded(near: [indexPath])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard indexPaths.count == 1, let indexPath = indexPaths.first, let item = newsItem(at: indexPath) else { return nil }
        return contextMenu(for: item)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfiguration configuration: UIContextMenuConfiguration,
        highlightPreviewForItemAt indexPath: IndexPath
    ) -> UITargetedPreview? {
        collectionView.cellForItem(at: indexPath).map(CardShape.targetedPreview(for:))
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfiguration configuration: UIContextMenuConfiguration,
        dismissalPreviewForItemAt indexPath: IndexPath
    ) -> UITargetedPreview? {
        collectionView.cellForItem(at: indexPath).map(CardShape.targetedPreview(for:))
    }
}

extension NewsFeedCollectionInteractions {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        dependencies.imagePrefetcher.prefetch(indexPaths.compactMap(imagePrefetch(at:)))
        loadMoreIfNeeded(near: indexPaths)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        dependencies.imagePrefetcher.cancelPrefetch(for: indexPaths.compactMap(newsID(at:)))
    }
}

extension NewsFeedCollectionInteractions {
    func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        newsItem(at: indexPath).map(NewsItemDrag.items(for:)) ?? []
    }

    func collectionView(
        _ collectionView: UICollectionView,
        dragPreviewParametersForItemAt indexPath: IndexPath
    ) -> UIDragPreviewParameters? {
        collectionView.cellForItem(at: indexPath).map(CardShape.dragPreviewParameters(for:))
    }
}
