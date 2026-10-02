import Foundation
import os

struct NewsPageDTO: Decodable, Sendable {
    let news: [NewsItemDTO]
    let totalCount: Int?

    private enum CodingKeys: String, CodingKey {
        case news, totalCount
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lossyItems = try container.decodeIfPresent([Lossy<NewsItemDTO>].self, forKey: .news) ?? []
        news = lossyItems.compactMap(\.value)
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount)
    }
}

struct NewsItemDTO: Decodable, Sendable {
    let id: Int
    let title: String?
    let description: String?
    let publishedDate: String?
    let url: String?
    let fullUrl: String?
    let titleImageUrl: String?
    let categoryType: String?
}

struct NewsArticleDTO: Decodable, Sendable {
    let item: NewsItemDTO
    let text: String?

    private enum CodingKeys: String, CodingKey {
        case text
    }

    init(from decoder: any Decoder) throws {
        item = try NewsItemDTO(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text)
    }
}

private struct Lossy<Value: Decodable & Sendable>: Decodable, Sendable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        do {
            value = try Value(from: decoder)
        } catch {
            DecodingLog.logger.error(
                "\(Constants.App.Diagnostics.skippedBrokenItem, privacy: .public) \(String(describing: Value.self)): \(error)"
            )
            value = nil
        }
    }
}

enum DecodingLog {
    static let logger = Logger(
        subsystem: Constants.App.Log.subsystem,
        category: Constants.App.Log.decodingCategory
    )
}
