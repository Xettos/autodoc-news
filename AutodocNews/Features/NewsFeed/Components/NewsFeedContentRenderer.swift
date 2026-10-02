import UIKit

@MainActor
protocol NewsFeedItemLocating: AnyObject {
    func sectionIdentifier(for sectionIndex: Int) -> NewsFeedSection?
    func newsID(at indexPath: IndexPath) -> NewsItem.ID?
    func feedIndex(for indexPath: IndexPath) -> Int?
    func imageSlot(at indexPath: IndexPath) -> NewsCardImageSlot?
    func cell(for itemID: NewsItem.ID) -> (any NewsCardDisplaying)?
}

@MainActor
protocol NewsFeedContentRendering: NewsFeedItemLocating {
    func apply(_ transition: NewsFeedStateTransition)
    func reconfigureVisibleNews()
}

@MainActor
final class NewsFeedContentRenderer: NewsFeedContentRendering {
    struct Dependencies {
        let viewModel: any NewsFeedViewModelProtocol
        let imageLoader: any ImageLoading
        let snapshotBuilder: any NewsFeedSnapshotBuilding
        let cardContentProvider: any NewsFeedCardContentProviding
        let imagePrefetcher: any NewsFeedImagePrefetching
    }

    private typealias DataSource = UICollectionViewDiffableDataSource<NewsFeedSection, NewsFeedItem>

    private weak var collectionView: UICollectionView?
    private let dependencies: Dependencies
    private var dataSource: DataSource?

    init(collectionView: UICollectionView, dependencies: Dependencies) {
        self.collectionView = collectionView
        self.dependencies = dependencies
        dataSource = makeDataSource(for: collectionView)
    }

    func apply(_ transition: NewsFeedStateTransition) {
        guard let dataSource else { return }
        let builder = dependencies.snapshotBuilder
        let isOnScreen = collectionView?.window != nil
        if let appended = builder.appending(to: dataSource.snapshot(), transition: transition) {
            dataSource.apply(appended, animatingDifferences: isOnScreen)
        } else if transition.requiresFullReload {
            reloadAll(with: builder.snapshot(for: transition.current))
        } else {
            dataSource.apply(builder.snapshot(for: transition.current), animatingDifferences: isOnScreen)
        }
    }

    func reconfigureVisibleNews() {
        guard let dataSource, let collectionView else { return }
        let visibleNews = collectionView.indexPathsForVisibleItems.compactMap(newsID(at:)).map(NewsFeedItem.news)
        guard !visibleNews.isEmpty else { return }
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(visibleNews)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func sectionIdentifier(for sectionIndex: Int) -> NewsFeedSection? {
        dataSource?.sectionIdentifier(for: sectionIndex)
    }

    func newsID(at indexPath: IndexPath) -> NewsItem.ID? {
        guard case .news(let itemID)? = dataSource?.itemIdentifier(for: indexPath) else { return nil }
        return itemID
    }

    func feedIndex(for indexPath: IndexPath) -> Int? {
        guard newsID(at: indexPath) != nil, let section = sectionIdentifier(for: indexPath.section) else { return nil }
        return dependencies.snapshotBuilder.itemIndex(for: indexPath, in: section)
    }

    func imageSlot(at indexPath: IndexPath) -> NewsCardImageSlot? {
        guard
            let collectionView,
            let section = sectionIdentifier(for: indexPath.section),
            let itemSize = collectionView.layoutAttributesForItem(at: indexPath)?.size
        else { return nil }
        return NewsCardImageSlot(section: section, itemSize: itemSize, traitCollection: collectionView.traitCollection)
    }

    func cell(for itemID: NewsItem.ID) -> (any NewsCardDisplaying)? {
        guard let indexPath = dataSource?.indexPath(for: .news(itemID)) else { return nil }
        return collectionView?.cellForItem(at: indexPath) as? any NewsCardDisplaying
    }

    private func reloadAll(with snapshot: NewsFeedSnapshot) {
        dependencies.imagePrefetcher.forgetIssuedRequests()
        dataSource?.applySnapshotUsingReloadData(snapshot)
    }

    private func makeDataSource(for collectionView: UICollectionView) -> DataSource {
        let registrations = NewsFeedCellRegistrations(imageLoader: dependencies.imageLoader, handlers: makeHandlers())
        return DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            registrations.cell(in: collectionView, at: indexPath, for: item)
        }
    }

    private func makeHandlers() -> NewsFeedCellRegistrations.Handlers {
        NewsFeedCellRegistrations.Handlers(
            sectionForIndex: { [weak self] index in self?.sectionIdentifier(for: index) },
            cardContent: { [weak self] itemID, indexPath in self?.cardContent(for: itemID, at: indexPath) },
            pagingFailureMessage: { [weak self] in self?.pagingFailureMessage ?? Constants.Feed.Text.fallbackErrorMessage },
            retryPaging: { [weak self] in self?.dependencies.viewModel.retryNextPage() }
        )
    }

    private func cardContent(for itemID: NewsItem.ID, at indexPath: IndexPath) -> NewsCardContent? {
        dependencies.cardContentProvider.cardContent(for: itemID, in: imageSlot(at: indexPath))
    }

    private var pagingFailureMessage: String? {
        guard case .failed(let message) = dependencies.viewModel.state.pagingFooter else { return nil }
        return message
    }
}
