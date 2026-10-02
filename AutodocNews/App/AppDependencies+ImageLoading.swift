import UIKit

extension AppDependencies {
    func makeImageLoader() -> any ImageLoading {
        ImagePipeline(
            memoryCache: ImageMemoryCache(costLimit: Self.imageMemoryCostLimit, notificationCenter: .default),
            fetcher: makeImageFetcher(),
            registry: ImageTaskRegistry(priorityBoost: .platformDefault)
        )
    }

    private func makeImageFetcher() -> some ImageFetching {
        ImageFetcher(
            transport: URLSession(configuration: .imageLoading),
            decoder: ImageDecoder(),
            decodeLimiter: ImageDecodeLimiter(maxConcurrentDecodes: Constants.ImageLoading.maxConcurrentDecodes),
            retryPolicy: Self.imageRetryPolicy
        )
    }

    private static var imageRetryPolicy: TransientRetryPolicy {
        TransientRetryPolicy(
            maxRetries: Constants.ImageLoading.transientRetryCount,
            delay: Constants.ImageLoading.transientRetryDelay,
            retryableCodes: Constants.ImageLoading.transientErrorCodes
        )
    }

    private static var imageMemoryCostLimit: Int {
        let share = ProcessInfo.processInfo.physicalMemory / Constants.ImageLoading.physicalMemoryDivisor
        return Int(min(share, UInt64(Constants.ImageLoading.memoryCostCap)))
    }
}

private extension URLSessionConfiguration {
    static var imageLoading: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = makeImageURLCache()
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = Constants.ImageLoading.requestTimeout
        configuration.timeoutIntervalForResource = Constants.ImageLoading.resourceTimeout
        configuration.httpMaximumConnectionsPerHost = Constants.ImageLoading.maxConnectionsPerHost
        return configuration
    }

    static func makeImageURLCache() -> URLCache {
        let directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appending(path: Constants.ImageLoading.urlCacheDirectoryName, directoryHint: .isDirectory)
        return URLCache(
            memoryCapacity: Constants.ImageLoading.urlCacheMemoryCapacity,
            diskCapacity: Constants.ImageLoading.urlCacheDiskCapacity,
            directory: directory
        )
    }
}
