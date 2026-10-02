import Foundation
import os
import Testing
@testable import AutodocNews

@Suite("APIClient", .timeLimit(.minutes(1)))
struct APIClientTests {
    private enum TestData {
        static let scriptedHost = "scripted.test"
        static let endpoint = NewsEndpoints.page(1, size: Constants.API.pageSize)
        static let validBody = Data(JSONFixtures.newsPage.utf8)
        static let fixtureItemCount = 2
    }

    @Test("a 2xx response is decoded", arguments: [200, 299])
    func decodesSuccess(statusCode: Int) async throws {
        let (client, stub) = try makeClient(response: .http(statusCode: statusCode, body: TestData.validBody))
        defer { stub.unregister() }

        let page = try await client.send(TestData.endpoint)

        #expect(page.news.count == TestData.fixtureItemCount)
    }

    @Test("a status outside 2xx throws httpStatus", arguments: [199, 300, 304, 404, 500, 503])
    func httpStatus(statusCode: Int) async throws {
        let (client, stub) = try makeClient(response: .http(statusCode: statusCode, body: TestData.validBody))
        defer { stub.unregister() }

        await #expect(throws: NetworkError.httpStatus(statusCode)) {
            try await client.send(TestData.endpoint)
        }
    }

    @Test("a non-HTTP response throws invalidResponse")
    func nonHTTPResponse() async throws {
        let client = try makeClient(replies: [.nonHTTP(body: TestData.validBody)])

        await #expect(throws: NetworkError.invalidResponse) {
            try await client.send(TestData.endpoint)
        }
    }

    @Test("a malformed body throws a decoding error")
    func decodingFailure() async throws {
        let (client, stub) = try makeClient(response: .http(statusCode: 200, body: Data("<html>".utf8)))
        defer { stub.unregister() }

        await #expect {
            try await client.send(TestData.endpoint)
        } throws: { error in
            guard case .decoding = error as? NetworkError else { return false }
            return true
        }
    }

    @Test("a transport failure maps to its NetworkError", arguments: [
        (URLError.Code.notConnectedToInternet, NetworkError.offline),
        (.timedOut, .timedOut),
        (.cannotFindHost, .transport(.cannotFindHost)),
    ])
    func transportFailure(code: URLError.Code, expected: NetworkError) async throws {
        let (client, stub) = try makeClient(response: .failure(code))
        defer { stub.unregister() }

        await #expect(throws: expected) {
            try await client.send(TestData.endpoint)
        }
    }

    @Test("URLError.cancelled without task cancellation is a transport failure")
    func spuriousURLCancellation() async throws {
        let (client, stub) = try makeClient(response: .failure(.cancelled))
        defer { stub.unregister() }

        await #expect(throws: NetworkError.transport(.cancelled)) {
            try await client.send(TestData.endpoint)
        }
    }

    @Test("cancelling an in-flight request throws CancellationError")
    func cancellation() async throws {
        let requestStarted = EventLog<Void>()
        let stub = URLProtocolStub.register(response: .hang) { _ in requestStarted.record(()) }
        defer { stub.unregister() }
        let client = try APIClient.stubbed(host: stub.host, transport: stub.session)
        let request = Task { try await client.send(TestData.endpoint) }

        try await requestStarted.wait { !$0.isEmpty }
        request.cancel()

        await #expect(throws: CancellationError.self) {
            try await request.value
        }
    }

    @Test("a response that arrives after cancellation is not decoded")
    func cancellationBeforeDecoding() async throws {
        let client = try makeClient(replies: [.httpAfterCancellingCaller(statusCode: 200, body: TestData.validBody)])

        await #expect(throws: CancellationError.self) {
            try await client.send(TestData.endpoint)
        }
    }

    private func makeClient(response: URLProtocolStub.Response) throws -> (APIClient, URLProtocolStub.Registration) {
        let stub = URLProtocolStub.register(response: response)
        return (try APIClient.stubbed(host: stub.host, transport: stub.session), stub)
    }

    private func makeClient(replies: [ScriptedTransport.Reply]) throws -> APIClient {
        try APIClient.stubbed(host: TestData.scriptedHost, transport: ScriptedTransport(replies: replies))
    }
}

@Suite("RemoteNewsRepository over APIClient", .timeLimit(.minutes(1)))
struct RemoteNewsRepositoryTests {
    private enum TestData {
        static let requestedPage = 3
        static let fixtureTotalCount = 1324
        static let articlePath = "avto-novosti/acura_nexera"
        static let articleID = 9073
    }

    @Test("fetchNews requests the page URL and maps DTOs to domain items")
    func fetchNews() async throws {
        let requestedURLs = OSAllocatedUnfairLock(initialState: [String]())
        let stub = URLProtocolStub.register(response: .http(statusCode: 200, body: Data(JSONFixtures.newsPage.utf8))) { request in
            requestedURLs.withLock { $0.append(request.url?.absoluteString ?? "") }
        }
        defer { stub.unregister() }
        let repository = try RemoteNewsRepository.stubbed(host: stub.host, transport: stub.session)

        let page = try await repository.fetchNews(page: TestData.requestedPage, pageSize: Constants.API.pageSize)

        #expect(requestedURLs.withLock { $0 } == ["https://\(stub.host)/api/news/\(TestData.requestedPage)/\(Constants.API.pageSize)"])
        #expect(page.totalCount == TestData.fixtureTotalCount)
        #expect(page.items.first?.title == "Acura NEXERA Vision — юбилейный концепт")
    }

    @Test("missing totalCount stays unknown and items without a path are dropped")
    func missingTotalCount() async throws {
        let stub = URLProtocolStub.register(
            response: .http(statusCode: 200, body: Data(JSONFixtures.pageWithBrokenAndSparseItems.utf8))
        )
        defer { stub.unregister() }
        let repository = try RemoteNewsRepository.stubbed(host: stub.host, transport: stub.session)

        let page = try await repository.fetchNews(page: Constants.API.firstPage, pageSize: Constants.API.pageSize)

        #expect(page.totalCount == nil)
        #expect(page.items.map(\.id) == [2])
    }

    @Test("fetchArticle requests news/item/{path} with the slash preserved")
    func fetchArticle() async throws {
        let requestedURLs = OSAllocatedUnfairLock(initialState: [String]())
        let stub = URLProtocolStub.register(response: .http(statusCode: 200, body: Data(JSONFixtures.article.utf8))) { request in
            requestedURLs.withLock { $0.append(request.url?.absoluteString ?? "") }
        }
        defer { stub.unregister() }
        let repository = try RemoteNewsRepository.stubbed(host: stub.host, transport: stub.session)

        let article = try await repository.fetchArticle(path: TestData.articlePath)

        #expect(requestedURLs.withLock { $0 } == ["https://\(stub.host)/api/news/item/\(TestData.articlePath)"])
        #expect(article.item.id == TestData.articleID)
        #expect(article.html.contains("NEXERA Vision"))
    }
}
