import Foundation
import Testing
@testable import AutodocNews

extension NewsDTOMapper {
    static let live = NewsDTOMapper(dateParser: NewsDateParser(), entityDecoder: HTMLEntityDecoder())
}

extension APIClient {
    static func stubbed(host: String, transport: any HTTPDataLoading) throws -> APIClient {
        let baseURL = try #require(URL(string: "https://\(host)/api/"))
        return APIClient(
            configuration: APIClientConfiguration(baseURL: baseURL, timeout: Constants.API.requestTimeout),
            transport: transport,
            decoder: JSONDecoder()
        )
    }
}

extension RemoteNewsRepository {
    static func stubbed(host: String, transport: any HTTPDataLoading) throws -> RemoteNewsRepository {
        RemoteNewsRepository(client: try APIClient.stubbed(host: host, transport: transport), mapper: NewsDTOMapper.live)
    }
}

struct FixedNewsDateParser: NewsDateParsing {
    let date: Date?

    func date(from string: String) -> Date? {
        date
    }
}
