import Foundation

protocol HTTPDataLoading: Sendable {
    func loadData(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataLoading {
    func loadData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request)
    }
}

protocol HTTPResponseFailure: Error {
    static var invalidResponse: Self { get }
    static func httpStatus(_ statusCode: Int) -> Self
}

extension URLResponse {
    func validateSuccess<Failure: HTTPResponseFailure>(throwing _: Failure.Type) throws(Failure) {
        guard let httpResponse = self as? HTTPURLResponse else {
            throw .invalidResponse
        }
        guard Constants.HTTP.successStatusCodes.contains(httpResponse.statusCode) else {
            throw .httpStatus(httpResponse.statusCode)
        }
    }
}

func isTaskCancellation(_ error: any Error) -> Bool {
    guard Task.isCancelled else { return false }
    return error is CancellationError || (error as? URLError)?.code == .cancelled
}
