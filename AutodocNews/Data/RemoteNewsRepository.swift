import Foundation

struct RemoteNewsRepository: NewsRepository {
    private let client: any APIClientProtocol
    private let mapper: any NewsDTOMapping

    init(client: any APIClientProtocol, mapper: any NewsDTOMapping) {
        self.client = client
        self.mapper = mapper
    }

    @concurrent
    func fetchNews(page: Int, pageSize: Int) async throws -> NewsPage {
        let dto = try await client.send(NewsEndpoints.page(page, size: pageSize))
        return mapper.page(from: dto)
    }

    @concurrent
    func fetchArticle(path: String) async throws -> NewsArticle {
        let dto = try await client.send(NewsEndpoints.article(path: path))
        return try mapper.article(from: dto)
    }
}
