import CoreGraphics

struct NewsFeedGrid: Equatable {
    private typealias Grid = Constants.Feed.Layout.Grid

    let containerWidth: CGFloat
    let columnCount: Int
    let horizontalInset: CGFloat

    init(containerWidth: CGFloat) {
        self.containerWidth = containerWidth
        columnCount = Self.columnCount(forContainerWidth: containerWidth)
        horizontalInset = columnCount == 1 ? Grid.compactHorizontalInset : Grid.wideHorizontalInset
    }

    var isWide: Bool { columnCount > 1 }

    var contentWidth: CGFloat {
        max(0, containerWidth - horizontalInset - horizontalInset)
    }

    var itemWidth: CGFloat {
        let spacingTotal = Grid.spacing * CGFloat(columnCount - 1)
        let available = contentWidth - spacingTotal
        return max(0, (available / CGFloat(columnCount)).rounded(.down))
    }

    private static func columnCount(forContainerWidth width: CGFloat) -> Int {
        let breakpoint = Grid.columnBreakpoints.first { width < $0.upperWidth }
        return breakpoint?.columnCount ?? Grid.maximumColumnCount
    }
}
