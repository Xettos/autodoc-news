import Foundation
import os

protocol APIClientProtocol: Sendable {
    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response
}

struct APIClientConfiguration: Sendable {
    let baseURL: URL
    let timeout: TimeInterval
}

struct APIClient: APIClientProtocol {
    private static let logger = Logger(
        subsystem: Constants.App.Log.subsystem,
        category: Constants.App.Log.networkingCategory
    )

    private let configuration: APIClientConfiguration
    private let transport: any HTTPDataLoading
    private let decoder: any ResponseDecoding

    init(configuration: APIClientConfiguration, transport: any HTTPDataLoading, decoder: any ResponseDecoding) {
        self.configuration = configuration
        self.transport = transport
        self.decoder = decoder
    }

    @concurrent
    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let request = endpoint.makeRequest(baseURL: configuration.baseURL, timeout: configuration.timeout)
        let (data, response) = try await load(request)
        try response.validateSuccess(throwing: NetworkError.self)
        try Task.checkCancellation()
        return try decode(Response.self, from: data, path: endpoint.path)
    }

    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await transport.loadData(for: request)
        } catch where isTaskCancellation(error) {
            throw CancellationError()
        } catch {
            throw NetworkError(error)
        }
    }

    private func decode<Response: Decodable>(_ type: Response.Type, from data: Data, path: String) throws -> Response {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            Self.logger.error("\(Constants.App.Diagnostics.decodingFailed, privacy: .public) \(path, privacy: .public): \(error)")
            throw NetworkError(error)
        }
    }
}
