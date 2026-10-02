import UIKit

struct ImageFetcher<
    Transport: HTTPDataLoading,
    Decoder: ImageDecoding,
    DecodeLimiter: ImageDecodeLimiting
>: ImageFetching {
    private let transport: Transport
    private let decoder: Decoder
    private let decodeLimiter: DecodeLimiter
    private let retryPolicy: TransientRetryPolicy

    init(transport: Transport, decoder: Decoder, decodeLimiter: DecodeLimiter, retryPolicy: TransientRetryPolicy) {
        self.transport = transport
        self.decoder = decoder
        self.decodeLimiter = decodeLimiter
        self.retryPolicy = retryPolicy
    }

    @concurrent
    func fetchImage(for request: ImageRequest) async throws -> UIImage {
        let data = try await download(from: request.url)
        try Task.checkCancellation()
        return try await decodeLimiter.run {
            try decoder.decode(data, for: request)
        }
    }

    private func download(from url: URL) async throws -> Data {
        let (data, response) = try await load(URLRequest(url: url), retriesLeft: retryPolicy.maxRetries)
        try response.validateSuccess(throwing: ImageLoadingError.self)
        guard !data.isEmpty else { throw ImageLoadingError.emptyData }
        return data
    }

    private func load(_ request: URLRequest, retriesLeft: Int) async throws -> (Data, URLResponse) {
        do {
            return try await transport.loadData(for: request)
        } catch where isTaskCancellation(error) {
            throw CancellationError()
        } catch let error as URLError where retryPolicy.shouldRetry(error, retriesLeft: retriesLeft) {
            try await Task.sleep(for: retryPolicy.delay)
            return try await load(request, retriesLeft: retriesLeft - 1)
        } catch let error as URLError {
            throw ImageLoadingError.transport(error.code)
        }
    }
}
