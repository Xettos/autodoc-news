import Foundation

struct TransientRetryPolicy: Sendable {
    let maxRetries: Int
    let delay: Duration
    let retryableCodes: Set<URLError.Code>

    func shouldRetry(_ error: URLError, retriesLeft: Int) -> Bool {
        retriesLeft > 0 && retryableCodes.contains(error.code)
    }
}
