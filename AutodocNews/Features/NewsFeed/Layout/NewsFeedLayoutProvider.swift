import UIKit

@MainActor
protocol NewsFeedLayoutProviding {
    func makeLayout(
        sectionForIndex: @escaping @MainActor (Int) -> NewsFeedSection?
    ) -> UICollectionViewCompositionalLayout

    func imageSize(
        forItemOfSize itemSize: CGSize,
        in section: NewsFeedSection,
        traitCollection: UITraitCollection
    ) -> CGSize
}

struct NewsFeedLayoutProvider: NewsFeedLayoutProviding {
    private typealias Sections = Constants.Feed.Layout.Sections
    private typealias Grid = Constants.Feed.Layout.Grid

    func makeLayout(
        sectionForIndex: @escaping @MainActor (Int) -> NewsFeedSection?
    ) -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = Sections.interSectionSpacing
        return UICollectionViewCompositionalLayout(
            sectionProvider: { index, environment in
                Self.makeSection(sectionForIndex(index) ?? Self.fallbackSection(), environment: environment)
            },
            configuration: configuration
        )
    }

    func imageSize(
        forItemOfSize itemSize: CGSize,
        in section: NewsFeedSection,
        traitCollection: UITraitCollection
    ) -> CGSize {
        switch section {
        case .featured: itemSize
        case .feed, .paging: NewsCardMetrics.metrics(for: traitCollection).imageSize(inCardOf: itemSize)
        }
    }

    private static func fallbackSection() -> NewsFeedSection {
        assertionFailure(Constants.Feed.Diagnostics.unknownSection)
        return .feed
    }

    private static func makeSection(
        _ section: NewsFeedSection,
        environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        let grid = NewsFeedGrid(containerWidth: environment.container.effectiveContentSize.width)
        let traits = environment.traitCollection
        let layoutSection = switch section {
        case .featured: featuredSection(grid: grid, traitCollection: traits)
        case .feed: feedSection(grid: grid, traitCollection: traits)
        case .paging: pagingSection()
        }
        layoutSection.contentInsets.leading = grid.horizontalInset
        layoutSection.contentInsets.trailing = grid.horizontalInset
        return layoutSection
    }

    private static func featuredSection(
        grid: NewsFeedGrid,
        traitCollection: UITraitCollection
    ) -> NSCollectionLayoutSection {
        let height = NewsFeaturedMetrics.height(
            forWidth: grid.contentWidth,
            isWide: grid.isWide,
            traitCollection: traitCollection
        )
        let section = singleItemSection(heightDimension: .absolute(height))
        section.contentInsets.top = Sections.featuredTopInset
        return section
    }

    private static func feedSection(grid: NewsFeedGrid, traitCollection: UITraitCollection) -> NSCollectionLayoutSection {
        let rowHeight = NewsCardMetrics.metrics(for: traitCollection).cardHeight(forWidth: grid.itemWidth)
        let section = NSCollectionLayoutSection(group: feedRow(height: rowHeight, grid: grid))
        section.interGroupSpacing = Grid.spacing
        section.contentInsets.bottom = Sections.bottomInset
        return section
    }

    private static func feedRow(height: CGFloat, grid: NewsFeedGrid) -> NSCollectionLayoutGroup {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .absolute(grid.itemWidth),
            heightDimension: .fractionalHeight(1)
        ))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(height)),
            repeatingSubitem: item,
            count: grid.columnCount
        )
        group.interItemSpacing = .fixed(Grid.spacing)
        return group
    }

    private static func pagingSection() -> NSCollectionLayoutSection {
        let section = singleItemSection(heightDimension: .estimated(Sections.pagingEstimatedHeight))
        section.contentInsets.bottom = Sections.bottomInset
        return section
    }

    private static func singleItemSection(heightDimension: NSCollectionLayoutDimension) -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: heightDimension)
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
        return NSCollectionLayoutSection(group: group)
    }
}
