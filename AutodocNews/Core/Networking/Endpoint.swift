import Foundation

struct Endpoint<Response: Decodable & Sendable>: Sendable {
    let path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []

    func makeRequest(baseURL: URL, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: makeURL(baseURL: baseURL), timeoutInterval: timeout)
        request.httpMethod = method.rawValue
        request.setValue(Constants.HTTP.jsonContentType, forHTTPHeaderField: Constants.HTTP.acceptHeader)
        return request
    }

    private func makeURL(baseURL: URL) -> URL {
        let url = baseURL.appending(path: path)
        guard !queryItems.isEmpty else { return url }
        return url.appending(queryItems: queryItems)
    }
}

enum HTTPMethod: String, Sendable {
    case get = "GET"
}
