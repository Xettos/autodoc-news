import Foundation
import Testing
@testable import AutodocNews

@Suite("Endpoints and request building")
struct EndpointTests {
    private let baseURL: URL

    init() throws {
        baseURL = try #require(URL(string: "https://webapi.autodoc.ru/api/"))
    }

    @Test("page endpoint builds news/{page}/{size}")
    func pageURL() {
        let request = NewsEndpoints.page(2, size: 15).makeRequest(baseURL: baseURL, timeout: 20)

        #expect(request.url?.absoluteString == "https://webapi.autodoc.ru/api/news/2/15")
    }

    @Test("article endpoint keeps the inner slash unescaped", arguments: [
        "avto-novosti/acura_nexera",
        "/avto-novosti/acura_nexera/",
    ])
    func articleURL(path: String) {
        let request = NewsEndpoints.article(path: path).makeRequest(baseURL: baseURL, timeout: 20)

        let url = request.url?.absoluteString
        #expect(url == "https://webapi.autodoc.ru/api/news/item/avto-novosti/acura_nexera")
        #expect(url?.contains("%2F") == false)
    }

    @Test("request is a JSON GET with the given timeout")
    func requestAttributes() {
        let request = NewsEndpoints.page(1, size: 15).makeRequest(baseURL: baseURL, timeout: 7)

        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.timeoutInterval == 7)
    }

    @Test("query items are appended to the URL")
    func queryItems() {
        let endpoint = Endpoint<NewsPageDTO>(path: "news/1/15", queryItems: [URLQueryItem(name: "q", value: "шины")])

        let request = endpoint.makeRequest(baseURL: baseURL, timeout: 20)

        #expect(request.url?.absoluteString == "https://webapi.autodoc.ru/api/news/1/15?q=%D1%88%D0%B8%D0%BD%D1%8B")
    }
}

@Suite("NetworkError mapping")
struct NetworkErrorTests {
    @Test("offline-like URL errors map to .offline", arguments: [
        URLError.Code.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
    ])
    func offline(code: URLError.Code) {
        #expect(NetworkError(URLError(code)) == .offline)
    }

    @Test("timeout maps to .timedOut")
    func timedOut() {
        #expect(NetworkError(URLError(.timedOut)) == .timedOut)
    }

    @Test("an existing NetworkError is passed through unchanged")
    func passthrough() {
        #expect(NetworkError(NetworkError.httpStatus(503)) == .httpStatus(503))
    }

    @Test("other errors map to .transport(.unknown)")
    func transport() {
        #expect(NetworkError(TestError.unexpected) == .transport(.unknown))
    }

    @Test("URL errors other than offline and timeout keep their code")
    func transportKeepsCode() {
        #expect(NetworkError(URLError(.cancelled)) == .transport(.cancelled))
    }

    @Test("every case has a user-facing description", arguments: [
        NetworkError.offline, .timedOut, .invalidResponse, .httpStatus(500), .decoding(codingPath: "news.0.id"), .transport(.unknown),
    ])
    func description(error: NetworkError) {
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("the HTTP status description names the status code")
    func httpStatusDescription() {
        #expect(NetworkError.httpStatus(500).errorDescription?.contains("500") == true)
    }
}
