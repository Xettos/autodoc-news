import Foundation
import Testing
import UIKit
@testable import AutodocNews

@Suite("ImagePipeline over injected components", .timeLimit(.minutes(1)))
struct ImagePipelineTests {
    private typealias CachingPipeline = ImagePipeline<StubImageMemoryCache, ScriptedImageLoad, ImageTaskRegistry>
    private typealias UncachedPipeline = ImagePipeline<NoopImageMemoryCache, ScriptedImageLoad, ImageTaskRegistry>

    private enum TestData {
        static let request = ImageRequest(url: URL(filePath: "/news/image.jpg"))
        static let displayPriority = TaskPriority.userInitiated
        static let secondDisplayPriority = TaskPriority.high
        static let firstDisplayPriority = TaskPriority.utility
    }

    private let memoryCache = StubImageMemoryCache()
    private let load = ScriptedImageLoad()

    @Test("a memory-cache hit is returned without fetching")
    func memoryHitSkipsFetch() async throws {
        let cached = UIImage()
        memoryCache.insert(cached, for: TestData.request)

        let image = try await makeCachingPipeline().image(for: TestData.request)

        #expect(image === cached)
        #expect(load.responder.calls.isEmpty)
    }

    @Test("a fetched image is stored in the memory cache")
    func missFetchesAndCaches() async throws {
        let fetched = UIImage()
        load.responder.enqueue(.success(fetched), for: TestData.request)

        let image = try await makeCachingPipeline().image(for: TestData.request)

        #expect(image === fetched)
        #expect(memoryCache.image(for: TestData.request) === fetched)
    }

    @Test("a failed fetch is not cached and the next request fetches again")
    func failureIsNotCached() async throws {
        let pipeline = makeCachingPipeline()
        load.responder.enqueue(.failure(ImageLoadingError.httpStatus(404)), for: TestData.request)
        load.responder.enqueue(.success(UIImage()), for: TestData.request)

        await #expect(throws: ImageLoadingError.httpStatus(404)) {
            try await pipeline.image(for: TestData.request)
        }
        #expect(memoryCache.image(for: TestData.request) == nil)
        _ = try await pipeline.image(for: TestData.request)

        #expect(load.responder.calls == [TestData.request, TestData.request])
    }

    @Test("prefetch skips images already in the memory cache")
    func prefetchSkipsCachedImages() {
        memoryCache.insert(UIImage(), for: TestData.request)

        makeCachingPipeline().prefetch([TestData.request])

        #expect(load.startCount == 0)
    }

    @Test("cancelling a prefetch nobody displays cancels its load")
    func cancelPrefetchCancelsLoad() async throws {
        let pipeline = makeCachingPipeline()
        pipeline.prefetch([TestData.request])
        await load.responder.waitForPendingCall(for: TestData.request)

        pipeline.cancelPrefetch([TestData.request])

        try await load.events.wait(for: .cancelled)
        #expect(memoryCache.image(for: TestData.request) == nil)
    }

    @available(iOS 26.0, *)
    @Test("a screen request during a prefetch joins the prefetch instead of fetching again")
    func screenRequestDuringPrefetchFetchesOnce() async throws {
        let pipeline = makeUncachedPipeline()
        let fetched = UIImage()
        pipeline.prefetch([TestData.request])
        await load.responder.waitForPendingCall(for: TestData.request)

        let displayed = try await load.startJoiningConsumer(escalatingTo: TestData.displayPriority) {
            Task(priority: TestData.displayPriority) { try await pipeline.image(for: TestData.request) }
        }
        load.responder.resolvePendingCall(for: TestData.request, with: .success(fetched))

        #expect(try await displayed.value === fetched)
        #expect(load.responder.calls == [TestData.request])
    }

    @available(iOS 26.0, *)
    @Test("two screens requesting the same image share one fetch and get the same image")
    func concurrentScreenRequestsFetchOnce() async throws {
        let pipeline = makeUncachedPipeline()
        let fetched = UIImage()
        let first = Task(priority: TestData.firstDisplayPriority) { try await pipeline.image(for: TestData.request) }
        await load.responder.waitForPendingCall(for: TestData.request)

        let second = try await load.startJoiningConsumer(escalatingTo: TestData.secondDisplayPriority) {
            Task(priority: TestData.secondDisplayPriority) { try await pipeline.image(for: TestData.request) }
        }
        load.responder.resolvePendingCall(for: TestData.request, with: .success(fetched))

        #expect(try await first.value === fetched)
        #expect(try await second.value === fetched)
        #expect(load.responder.calls == [TestData.request])
    }

    private func makeCachingPipeline() -> CachingPipeline {
        ImagePipeline(memoryCache: memoryCache, fetcher: load, registry: ImageTaskRegistry(priorityBoost: .escalate))
    }

    private func makeUncachedPipeline() -> UncachedPipeline {
        ImagePipeline(memoryCache: NoopImageMemoryCache(), fetcher: load, registry: ImageTaskRegistry(priorityBoost: .escalate))
    }
}
