import UIKit

@MainActor
struct NewsFeedCellRegistrations {
    struct Handlers {
        let sectionForIndex: (Int) -> NewsFeedSection?
        let cardContent: (NewsItem.ID, IndexPath) -> NewsCardContent?
        let pagingFailureMessage: () -> String
        let retryPaging: () -> Void
    }

    private let handlers: Handlers
    private let featured: UICollectionView.CellRegistration<NewsFeaturedCell, NewsItem.ID>
    private let card: UICollectionView.CellRegistration<NewsCardCell, NewsItem.ID>
    private let featuredSkeleton = UICollectionView.CellRegistration<NewsFeaturedSkeletonCell, Int> { _, _, _ in }
    private let cardSkeleton = UICollectionView.CellRegistration<NewsCardSkeletonCell, Int> { _, _, _ in }
    private let paging: UICollectionView.CellRegistration<NewsFeedPagingCell, NewsFeedPagingCell.Content>

    init(imageLoader: any ImageLoading, handlers: Handlers) {
        self.handlers = handlers
        featured = Self.newsRegistration(imageLoader: imageLoader, cardContent: handlers.cardContent)
        card = Self.newsRegistration(imageLoader: imageLoader, cardContent: handlers.cardContent)
        paging = UICollectionView.CellRegistration { cell, _, content in
            cell.configure(with: content, onRetry: handlers.retryPaging)
        }
    }

    func cell(
        in collectionView: UICollectionView,
        at indexPath: IndexPath,
        for item: NewsFeedItem
    ) -> UICollectionViewCell {
        let isFeatured = handlers.sectionForIndex(indexPath.section) == .featured
        switch item {
        case .news(let itemID) where isFeatured:
            return collectionView.dequeueConfiguredReusableCell(using: featured, for: indexPath, item: itemID)
        case .news(let itemID):
            return collectionView.dequeueConfiguredReusableCell(using: card, for: indexPath, item: itemID)
        case .placeholder(let index) where isFeatured:
            return collectionView.dequeueConfiguredReusableCell(using: featuredSkeleton, for: indexPath, item: index)
        case .placeholder(let index):
            return collectionView.dequeueConfiguredReusableCell(using: cardSkeleton, for: indexPath, item: index)
        case .pagingLoading:
            return collectionView.dequeueConfiguredReusableCell(using: paging, for: indexPath, item: .loading)
        case .pagingFailed:
            let content = NewsFeedPagingCell.Content.failed(message: handlers.pagingFailureMessage())
            return collectionView.dequeueConfiguredReusableCell(using: paging, for: indexPath, item: content)
        }
    }

    private static func newsRegistration<Cell: NewsCardDisplaying>(
        imageLoader: any ImageLoading,
        cardContent: @escaping (NewsItem.ID, IndexPath) -> NewsCardContent?
    ) -> UICollectionView.CellRegistration<Cell, NewsItem.ID> {
        UICollectionView.CellRegistration { cell, indexPath, itemID in
            guard let content = cardContent(itemID, indexPath) else { return cell.resetContent() }
            cell.configure(with: content, imageLoader: imageLoader)
        }
    }
}
