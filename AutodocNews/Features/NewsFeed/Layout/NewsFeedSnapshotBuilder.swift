import UIKit

typealias NewsFeedSnapshot = NSDiffableDataSourceSnapshot<NewsFeedSection, NewsFeedItem>

protocol NewsFeedSnapshotBuilding {
    func snapshot(for state: NewsFeedViewState) -> NewsFeedSnapshot
    func appending(to snapshot: NewsFeedSnapshot, transition: NewsFeedStateTransition) -> NewsFeedSnapshot?
    func itemIndex(for indexPath: IndexPath, in section: NewsFeedSection) -> Int?
}

struct NewsFeedSnapshotBuilder: NewsFeedSnapshotBuilding {
    private typealias Sections = Constants.Feed.Layout.Sections

    func snapshot(for state: NewsFeedViewState) -> NewsFeedSnapshot {
        switch state.phase {
        case .initialLoading:
            placeholderSnapshot()
        case .content:
            contentSnapshot(itemIDs: state.itemIDs, pagingFooter: state.pagingFooter)
        case .empty, .failed:
            NewsFeedSnapshot()
        }
    }

    func appending(to snapshot: NewsFeedSnapshot, transition: NewsFeedStateTransition) -> NewsFeedSnapshot? {
        guard let shownCount = shownNewsCount(in: snapshot, ifAppendableBy: transition) else { return nil }
        var updated = snapshot
        appendNews(transition.current.itemIDs.dropFirst(shownCount), afterCount: shownCount, to: &updated)
        replacePagingFooter(with: transition.current.pagingFooter, in: &updated)
        return updated
    }

    func itemIndex(for indexPath: IndexPath, in section: NewsFeedSection) -> Int? {
        switch section {
        case .featured: indexPath.item
        case .feed: Sections.featuredItemCount + indexPath.item
        case .paging: nil
        }
    }

    private func placeholderSnapshot() -> NewsFeedSnapshot {
        let feedPlaceholders = (1...Constants.Feed.Layout.Skeleton.feedPlaceholderCount).map(NewsFeedItem.placeholder)
        var snapshot = NewsFeedSnapshot()
        snapshot.appendSections([.featured, .feed])
        snapshot.appendItems([.placeholder(0)], toSection: .featured)
        snapshot.appendItems(feedPlaceholders, toSection: .feed)
        return snapshot
    }

    private func contentSnapshot(
        itemIDs: [NewsItem.ID],
        pagingFooter: NewsFeedViewState.PagingFooter
    ) -> NewsFeedSnapshot {
        var snapshot = NewsFeedSnapshot()
        snapshot.appendSections([.featured, .feed])
        appendNews(itemIDs[...], afterCount: 0, to: &snapshot)
        appendPagingFooter(pagingFooter, to: &snapshot)
        return snapshot
    }

    private func shownNewsCount(
        in snapshot: NewsFeedSnapshot,
        ifAppendableBy transition: NewsFeedStateTransition
    ) -> Int? {
        guard
            let previous = transition.previous,
            !transition.requiresFullReload,
            transition.current.phase == .content,
            newsCount(in: snapshot) == previous.itemIDs.count,
            transition.current.itemIDs.starts(with: previous.itemIDs)
        else { return nil }
        return previous.itemIDs.count
    }

    private func newsCount(in snapshot: NewsFeedSnapshot) -> Int? {
        let sections = snapshot.sectionIdentifiers
        guard sections.contains(.featured), sections.contains(.feed) else { return nil }
        return snapshot.numberOfItems(inSection: .featured) + snapshot.numberOfItems(inSection: .feed)
    }

    private func appendNews(
        _ itemIDs: ArraySlice<NewsItem.ID>,
        afterCount existingCount: Int,
        to snapshot: inout NewsFeedSnapshot
    ) {
        let featuredRoom = max(0, Sections.featuredItemCount - existingCount)
        snapshot.appendItems(itemIDs.prefix(featuredRoom).map(NewsFeedItem.news), toSection: .featured)
        snapshot.appendItems(itemIDs.dropFirst(featuredRoom).map(NewsFeedItem.news), toSection: .feed)
    }

    private func replacePagingFooter(with footer: NewsFeedViewState.PagingFooter, in snapshot: inout NewsFeedSnapshot) {
        if snapshot.sectionIdentifiers.contains(.paging) {
            snapshot.deleteSections([.paging])
        }
        appendPagingFooter(footer, to: &snapshot)
    }

    private func appendPagingFooter(_ footer: NewsFeedViewState.PagingFooter, to snapshot: inout NewsFeedSnapshot) {
        guard let pagingItem = pagingItem(for: footer) else { return }
        snapshot.appendSections([.paging])
        snapshot.appendItems([pagingItem], toSection: .paging)
    }

    private func pagingItem(for footer: NewsFeedViewState.PagingFooter) -> NewsFeedItem? {
        switch footer {
        case .hidden: nil
        case .loading: .pagingLoading
        case .failed: .pagingFailed
        }
    }
}
