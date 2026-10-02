import Foundation

extension AppDependencies {
    func makeNewsRepository() -> any NewsRepository {
        RemoteNewsRepository(client: makeAPIClient(), mapper: makeDTOMapper())
    }

    private func makeAPIClient() -> any APIClientProtocol {
        APIClient(
            configuration: Self.apiConfiguration,
            transport: URLSession(configuration: .newsAPI),
            decoder: JSONDecoder()
        )
    }

    private func makeDTOMapper() -> any NewsDTOMapping {
        NewsDTOMapper(dateParser: NewsDateParser(), entityDecoder: HTMLEntityDecoder())
    }

    private static var apiConfiguration: APIClientConfiguration {
        guard let baseURL = URL(string: Constants.API.baseURLString) else {
            preconditionFailure(Constants.App.Diagnostics.invalidBaseURL)
        }
        return APIClientConfiguration(baseURL: baseURL, timeout: Constants.API.requestTimeout)
    }
}

private extension URLSessionConfiguration {
    static var newsAPI: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = Constants.API.requestTimeout
        configuration.timeoutIntervalForResource = Constants.API.resourceTimeout
        configuration.httpMaximumConnectionsPerHost = Constants.API.maxConnectionsPerHost
        return configuration
    }
}
