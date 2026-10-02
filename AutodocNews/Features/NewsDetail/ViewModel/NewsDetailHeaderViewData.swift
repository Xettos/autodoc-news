import Foundation

struct NewsDetailHeaderViewData: Equatable, Sendable {
    let title: String
    let category: String?
    let publishedDateText: String?
    let summary: String?
    let imageURL: URL?
    let webURL: URL?
}
