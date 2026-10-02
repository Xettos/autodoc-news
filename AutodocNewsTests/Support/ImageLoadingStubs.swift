import Foundation
import os
import Testing
import UIKit
@testable import AutodocNews

final class StubImageMemoryCache: ImageMemoryCaching {
    private let storage = OSAllocatedUnfairLock(initialState: [ImageRequest: UIImage]())

    func image(for request: ImageRequest) -> UIImage? {
        storage.withLock { $0[request] }
    }

    func largestImage(for url: URL) -> UIImage? {
        storage.withLock { storage in storage.first { $0.key.url == url }?.value }
    }

    func insert(_ image: UIImage, for request: ImageRequest) {
        storage.withLock { $0[request] = image }
    }
}

struct NoopImageMemoryCache: ImageMemoryCaching {
    func image(for request: ImageRequest) -> UIImage? { nil }
    func largestImage(for url: URL) -> UIImage? { nil }
    func insert(_ image: UIImage, for request: ImageRequest) {}
}

final class ScriptedImageLoad: ImageFetching {
    enum Event: Equatable, Sendable {
        case started
        case cancelled
        case escalated(to: TaskPriority)
    }

    let responder = ScriptedResponder<ImageRequest, UIImage>()
    let events = EventLog<Event>()

    var operation: ImageLoadOperation {
        { [self] request in try await load(request) }
    }

    var startCount: Int { events.count(of: .started) }

    func fetchImage(for request: ImageRequest) async throws -> UIImage {
        try await load(request)
    }

    @available(iOS 26.0, *)
    func startJoiningConsumer<Value>(
        escalatingTo priority: TaskPriority,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ startConsumer: () -> Task<Value, any Error>
    ) async throws -> Task<Value, any Error> {
        let startsBefore = startCount
        let consumer = startConsumer()
        let events = try await events.wait { events in
            events.contains(.escalated(to: priority)) || events.count { $0 == .started } > startsBefore
        }
        let isLoadedAgain = events.count { $0 == .started } > startsBefore
        if isLoadedAgain {
            consumer.cancel()
        }
        try #require(!isLoadedAgain, "The consumer started its own load instead of joining the in-flight one", sourceLocation: sourceLocation)
        return consumer
    }

    private func load(_ request: ImageRequest) async throws -> UIImage {
        events.record(.started)
        do {
            return try await respondReportingEscalation(to: request)
        } catch is CancellationError {
            events.record(.cancelled)
            throw CancellationError()
        }
    }

    private func respondReportingEscalation(to request: ImageRequest) async throws -> UIImage {
        guard #available(iOS 26.0, *) else {
            return try await responder.respond(to: request)
        }
        return try await withTaskPriorityEscalationHandler {
            try await responder.respond(to: request)
        } onPriorityEscalated: { [events] _, newPriority in
            events.record(.escalated(to: newPriority))
        }
    }
}

struct StubImageDecoder: ImageDecoding {
    let result: Result<UIImage, ImageLoadingError>

    func decode(_ data: Data, for request: ImageRequest) throws(ImageLoadingError) -> UIImage {
        try result.get()
    }
}

final class ScriptedTransport: HTTPDataLoading {
    enum Reply: Sendable {
        case http(statusCode: Int, body: Data)
        case nonHTTP(body: Data)
        case failure(URLError.Code)
        case httpAfterCancellingCaller(statusCode: Int, body: Data)
    }

    private static let httpVersion = "HTTP/1.1"

    private let replies: OSAllocatedUnfairLock<[Reply]>
    private let requests = OSAllocatedUnfairLock(initialState: [URLRequest]())

    init(replies: [Reply]) {
        self.replies = OSAllocatedUnfairLock(initialState: replies)
    }

    var requestCount: Int {
        requests.withLock { $0.count }
    }

    func loadData(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.withLock { $0.append(request) }
        let reply = replies.withLock { $0.isEmpty ? nil : $0.removeFirst() }
        guard let reply, let url = request.url else {
            Issue.record("Unexpected request \(String(describing: request.url)): no scripted reply left")
            throw URLError(.resourceUnavailable)
        }
        return try answer(reply, for: url)
    }

    private func answer(_ reply: Reply, for url: URL) throws -> (Data, URLResponse) {
        switch reply {
        case .http(let statusCode, let body):
            return (body, try httpResponse(url: url, statusCode: statusCode))
        case .nonHTTP(let body):
            return (body, URLResponse(url: url, mimeType: nil, expectedContentLength: body.count, textEncodingName: nil))
        case .failure(let code):
            throw URLError(code)
        case .httpAfterCancellingCaller(let statusCode, let body):
            withUnsafeCurrentTask { $0?.cancel() }
            return (body, try httpResponse(url: url, statusCode: statusCode))
        }
    }

    private func httpResponse(url: URL, statusCode: Int) throws -> HTTPURLResponse {
        try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: Self.httpVersion, headerFields: nil))
    }
}

final class ScriptedImageLoader: ImageLoading {
    enum CancellationBehavior: Sendable {
        case cooperative
        case ignored
    }

    let responder = ScriptedResponder<ImageRequest, UIImage>()
    private let memoryCache = StubImageMemoryCache()
    private let cancellationBehavior: CancellationBehavior

    init(cancellationBehavior: CancellationBehavior = .cooperative) {
        self.cancellationBehavior = cancellationBehavior
    }

    func cache(_ image: UIImage, for request: ImageRequest) {
        memoryCache.insert(image, for: request)
    }

    func cachedImage(for request: ImageRequest) -> UIImage? {
        memoryCache.image(for: request)
    }

    func cachedImage(forURL url: URL) -> UIImage? {
        memoryCache.largestImage(for: url)
    }

    func image(for request: ImageRequest) async throws -> UIImage {
        switch cancellationBehavior {
        case .cooperative:
            try await responder.respond(to: request)
        case .ignored:
            try await Task { [responder] in try await responder.respond(to: request) }.value
        }
    }

    func prefetch(_ requests: [ImageRequest]) {}

    func cancelPrefetch(_ requests: [ImageRequest]) {}
}
