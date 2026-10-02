import os
import UIKit

final class ImagePipeline<
    MemoryCache: ImageMemoryCaching,
    Fetcher: ImageFetching,
    Registry: ImageTaskDeduplicating
>: ImageLoading {
    private static var logger: Logger {
        Logger(subsystem: Constants.App.Log.subsystem, category: Constants.App.Log.imageLoadingCategory)
    }

    private let memoryCache: MemoryCache
    private let registry: Registry
    private let loadOperation: ImageLoadOperation

    init(memoryCache: MemoryCache, fetcher: Fetcher, registry: Registry) {
        self.memoryCache = memoryCache
        self.registry = registry
        self.loadOperation = Self.makeLoadOperation(fetcher: fetcher, memoryCache: memoryCache)
    }

    func cachedImage(for request: ImageRequest) -> UIImage? {
        memoryCache.image(for: request)
    }

    func cachedImage(forURL url: URL) -> UIImage? {
        memoryCache.largestImage(for: url)
    }

    func image(for request: ImageRequest) async throws -> UIImage {
        if let cached = memoryCache.image(for: request) {
            return cached
        }
        return try await registry.image(for: job(for: request, priority: Task.currentPriority))
    }

    func prefetch(_ requests: [ImageRequest]) {
        for request in requests where memoryCache.image(for: request) == nil {
            registry.prefetch(job(for: request, priority: .utility))
        }
    }

    func cancelPrefetch(_ requests: [ImageRequest]) {
        for request in requests {
            registry.cancelPrefetch(request)
        }
    }

    private func job(for request: ImageRequest, priority: TaskPriority) -> ImageLoadJob {
        ImageLoadJob(request: request, priority: priority, operation: loadOperation)
    }

    private static func makeLoadOperation(fetcher: Fetcher, memoryCache: MemoryCache) -> ImageLoadOperation {
        { request in
            if let cached = memoryCache.image(for: request) {
                return cached
            }
            let image = try await fetchLogged(request, using: fetcher)
            memoryCache.insert(image, for: request)
            return image
        }
    }

    private static func fetchLogged(_ request: ImageRequest, using fetcher: Fetcher) async throws -> UIImage {
        do {
            return try await fetcher.fetchImage(for: request)
        } catch {
            if !(error is CancellationError) {
                logFailure(error, for: request)
            }
            throw error
        }
    }

    private static func logFailure(_ error: any Error, for request: ImageRequest) {
        let host = request.url.host() ?? ""
        let path = request.url.path()
        logger.error("""
            \(Constants.App.Diagnostics.imageLoadFailed, privacy: .public) \
            \(host, privacy: .public)\(path, privacy: .public): \(String(describing: error), privacy: .public)
            """)
    }
}
