import Foundation
import os

protocol NewsDTOMapping: Sendable {
    func item(from dto: NewsItemDTO) throws(NewsMappingError) -> NewsItem
    func page(from dto: NewsPageDTO) -> NewsPage
    func article(from dto: NewsArticleDTO) throws(NewsMappingError) -> NewsArticle
}

extension NewsDTOMapping {
    func page(from dto: NewsPageDTO) -> NewsPage {
        NewsPage(items: dto.news.compactMap(itemSkippingUnmappable(from:)), totalCount: dto.totalCount)
    }

    func article(from dto: NewsArticleDTO) throws(NewsMappingError) -> NewsArticle {
        guard let html = dto.text, !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            log(.missingArticleBody, itemID: dto.item.id)
            throw .missingArticleBody
        }
        return NewsArticle(item: try item(from: dto.item), html: html)
    }

    private func itemSkippingUnmappable(from dto: NewsItemDTO) -> NewsItem? {
        do throws(NewsMappingError) {
            return try item(from: dto)
        } catch {
            log(error, itemID: dto.id)
            return nil
        }
    }

    private func log(_ error: NewsMappingError, itemID: Int) {
        let message = switch error {
        case .missingPath: Constants.App.Diagnostics.skippedUnmappableItem
        case .missingArticleBody: Constants.App.Diagnostics.unmappableArticle
        }
        DecodingLog.logger.error("\(message, privacy: .public) \(itemID)")
    }
}

struct NewsDTOMapper: NewsDTOMapping {
    private let dateParser: any NewsDateParsing
    private let entityDecoder: any HTMLEntityDecoding

    init(dateParser: any NewsDateParsing, entityDecoder: any HTMLEntityDecoding) {
        self.dateParser = dateParser
        self.entityDecoder = entityDecoder
    }

    func item(from dto: NewsItemDTO) throws(NewsMappingError) -> NewsItem {
        NewsItem(
            id: dto.id,
            title: cleanText(dto.title),
            summary: cleanText(dto.description),
            publishedAt: dto.publishedDate.flatMap(dateParser.date(from:)),
            path: try path(from: dto.url),
            webURL: absoluteURL(from: dto.fullUrl),
            imageURL: absoluteURL(from: dto.titleImageUrl),
            category: cleanText(dto.categoryType)
        )
    }

    private func cleanText(_ raw: String?) -> String {
        guard let raw else { return "" }
        return entityDecoder.decode(raw).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func path(from raw: String?) throws(NewsMappingError) -> String {
        let separators = CharacterSet(charactersIn: Constants.API.Path.separator)
        let path = raw?.trimmingCharacters(in: separators.union(.whitespacesAndNewlines)) ?? ""
        guard !path.isEmpty else { throw .missingPath }
        return path
    }

    private func absoluteURL(from raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host() != nil else { return nil }
        return url
    }
}
