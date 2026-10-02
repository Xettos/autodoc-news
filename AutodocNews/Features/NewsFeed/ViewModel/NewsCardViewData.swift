import Foundation

struct NewsCardViewData: Equatable, Sendable {
    let title: String
    let category: String
    let dateText: String
    let imageURL: URL?
    let accessibilityLabel: String
}

protocol NewsCardViewDataMapping: Sendable {
    func viewData(for item: NewsItem) -> NewsCardViewData
}

struct NewsCardViewDataMapper: NewsCardViewDataMapping {
    private let dateFormatter: any NewsDateFormatting

    init(dateFormatter: any NewsDateFormatting) {
        self.dateFormatter = dateFormatter
    }

    func viewData(for item: NewsItem) -> NewsCardViewData {
        let dateText = item.publishedAt.map(dateFormatter.string(from:)) ?? ""
        return NewsCardViewData(
            title: item.title,
            category: item.category,
            dateText: dateText,
            imageURL: item.imageURL,
            accessibilityLabel: Self.accessibilityLabel(for: item, dateText: dateText)
        )
    }

    private static func accessibilityLabel(for item: NewsItem, dateText: String) -> String {
        [item.category, item.title, dateText]
            .filter { !$0.isEmpty }
            .joined(separator: Constants.Feed.Text.accessibilityLabelSeparator)
    }
}
