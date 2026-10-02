import Foundation
import Testing
import UIKit
@testable import AutodocNews

@Suite("ImageFetcher", .timeLimit(.minutes(1)))
struct ImageFetcherTests {
    private enum TestData {
        static let scriptedHost = "images.test"
        static let imagePath = "/news/image.jpg"
        static let body = Data("jpeg bytes".utf8)
        static let okStatus = 200
        static let notFoundStatus = 404
        static let decodeSlots = 1
        static let singleAttempt = 1
        static let attemptsWithRetry = 1 + Constants.ImageLoading.transientRetryCount
    }

    private let decodedImage = UIImage()

    @Test("a 2xx response with a body is decoded")
    func decodesSuccess() async throws {
        let stub = URLProtocolStub.register(response: .http(statusCode: TestData.okStatus, body: TestData.body))
        defer { stub.unregister() }

        let image = try await makeFetcher(transport: stub.session).fetchImage(for: try request(on: stub.host))

        #expect(image === decodedImage)
    }

    @Test("a status outside 2xx throws httpStatus without a retry", arguments: [199, 300, 404, 500])
    func rejectsStatus(statusCode: Int) async throws {
        let transport = ScriptedTransport(replies: [.http(statusCode: statusCode, body: TestData.body)])

        await #expect(throws: ImageLoadingError.httpStatus(statusCode)) {
            try await makeFetcher(transport: transport).fetchImage(for: try request())
        }
        #expect(transport.requestCount == TestData.singleAttempt)
    }

    @Test("a non-HTTP response throws invalidResponse")
    func rejectsNonHTTPResponse() async throws {
        let transport = ScriptedTransport(replies: [.nonHTTP(body: TestData.body)])

        await #expect(throws: ImageLoadingError.invalidResponse) {
            try await makeFetcher(transport: transport).fetchImage(for: try request())
        }
    }

    @Test("an empty body throws emptyData")
    func rejectsEmptyBody() async throws {
        let stub = URLProtocolStub.register(response: .http(statusCode: TestData.okStatus, body: Data()))
        defer { stub.unregister() }

        await #expect(throws: ImageLoadingError.emptyData) {
            try await makeFetcher(transport: stub.session).fetchImage(for: try request(on: stub.host))
        }
    }

    @Test("a decoding failure is passed through")
    func passesDecodingFailure() async throws {
        let transport = ScriptedTransport(replies: [.http(statusCode: TestData.okStatus, body: TestData.body)])
        let fetcher = makeFetcher(transport: transport, decoder: StubImageDecoder(result: .failure(.decodingFailed)))

        await #expect(throws: ImageLoadingError.decodingFailed) {
            try await fetcher.fetchImage(for: try request())
        }
    }

    @Test("a transient failure is retried once and then succeeds", arguments: [URLError.Code.timedOut, .networkConnectionLost])
    func retriesTransientFailure(code: URLError.Code) async throws {
        let transport = ScriptedTransport(replies: [.failure(code), .http(statusCode: TestData.okStatus, body: TestData.body)])

        let image = try await makeFetcher(transport: transport).fetchImage(for: try request())

        #expect(image === decodedImage)
        #expect(transport.requestCount == TestData.attemptsWithRetry)
    }

    @Test("a transient failure that repeats is reported after a single retry")
    func retriesOnlyOnce() async throws {
        let transport = ScriptedTransport(replies: Array(repeating: .failure(.timedOut), count: TestData.attemptsWithRetry))

        await #expect(throws: ImageLoadingError.transport(.timedOut)) {
            try await makeFetcher(transport: transport).fetchImage(for: try request())
        }
        #expect(transport.requestCount == TestData.attemptsWithRetry)
    }

    @Test("a non-transient failure is not retried")
    func skipsRetryForOtherFailures() async throws {
        let transport = ScriptedTransport(replies: [.failure(.notConnectedToInternet)])

        await #expect(throws: ImageLoadingError.transport(.notConnectedToInternet)) {
            try await makeFetcher(transport: transport).fetchImage(for: try request())
        }
        #expect(transport.requestCount == TestData.singleAttempt)
    }

    @Test("URLError.cancelled without task cancellation is a transport failure")
    func spuriousURLCancellation() async throws {
        let stub = URLProtocolStub.register(response: .failure(.cancelled))
        defer { stub.unregister() }

        await #expect(throws: ImageLoadingError.transport(.cancelled)) {
            try await makeFetcher(transport: stub.session).fetchImage(for: try request(on: stub.host))
        }
    }

    @Test("cancelling the task during the download throws CancellationError")
    func taskCancellation() async throws {
        let requestStarted = EventLog<Void>()
        let stub = URLProtocolStub.register(response: .hang) { _ in requestStarted.record(()) }
        defer { stub.unregister() }
        let fetcher = makeFetcher(transport: stub.session)
        let imageRequest = try request(on: stub.host)
        let download = Task { try await fetcher.fetchImage(for: imageRequest) }

        try await requestStarted.wait { !$0.isEmpty }
        download.cancel()

        await #expect(throws: CancellationError.self) { try await download.value }
    }

    @Test("a response that arrives after cancellation is not decoded")
    func cancellationBeforeDecoding() async throws {
        let transport = ScriptedTransport(replies: [.httpAfterCancellingCaller(statusCode: TestData.okStatus, body: TestData.body)])

        await #expect(throws: CancellationError.self) {
            try await makeFetcher(transport: transport).fetchImage(for: try request())
        }
    }

    private func makeFetcher<Transport: HTTPDataLoading>(
        transport: Transport,
        decoder: StubImageDecoder? = nil
    ) -> ImageFetcher<Transport, StubImageDecoder, ImageDecodeLimiter> {
        ImageFetcher(
            transport: transport,
            decoder: decoder ?? StubImageDecoder(result: .success(decodedImage)),
            decodeLimiter: ImageDecodeLimiter(maxConcurrentDecodes: TestData.decodeSlots),
            retryPolicy: TransientRetryPolicy(
                maxRetries: Constants.ImageLoading.transientRetryCount,
                delay: .zero,
                retryableCodes: Constants.ImageLoading.transientErrorCodes
            )
        )
    }

    private func request(on host: String = TestData.scriptedHost) throws -> ImageRequest {
        ImageRequest(url: try #require(URL(string: "https://\(host)\(TestData.imagePath)")))
    }
}
