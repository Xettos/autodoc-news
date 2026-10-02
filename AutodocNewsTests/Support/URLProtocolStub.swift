import Foundation
import os

final class URLProtocolStub: URLProtocol {
    enum Response: Sendable {
        case http(statusCode: Int, body: Data)
        case failure(URLError.Code)
        case hang
    }

    struct Handler: Sendable {
        let response: Response
        let onRequest: @Sendable (URLRequest) -> Void
    }

    struct Registration: Sendable {
        let host: String
        let session: URLSession

        func unregister() {
            URLProtocolStub.state.withLock { _ = $0.handlers.removeValue(forKey: host) }
        }
    }

    private struct State {
        var handlers: [String: Handler] = [:]
        var lastRegistrationID = 0
    }

    private static let hostSuffix = ".stub.test"
    private static let state = OSAllocatedUnfairLock(initialState: State())

    static func register(
        response: Response,
        onRequest: @escaping @Sendable (URLRequest) -> Void = { _ in }
    ) -> Registration {
        let handler = Handler(response: response, onRequest: onRequest)
        let host = state.withLock { state in
            state.lastRegistrationID += 1
            let host = "host-\(state.lastRegistrationID)\(hostSuffix)"
            state.handlers[host] = handler
            return host
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return Registration(host: host, session: URLSession(configuration: configuration))
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host(),
              let handler = Self.state.withLock({ $0.handlers[host] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        handler.onRequest(request)
        respond(with: handler.response, for: url)
    }

    override func stopLoading() {}

    private func respond(with response: Response, for url: URL) {
        switch response {
        case .http(let statusCode, let body):
            let httpResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)
            if let httpResponse {
                client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .hang:
            break
        }
    }
}
