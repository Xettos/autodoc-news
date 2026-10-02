import UIKit

protocol ImageMemoryCaching: Sendable {
    func image(for request: ImageRequest) -> UIImage?
    func largestImage(for url: URL) -> UIImage?
    func insert(_ image: UIImage, for request: ImageRequest)
}

protocol ImageFetching: Sendable {
    func fetchImage(for request: ImageRequest) async throws -> UIImage
}

protocol ImageDecoding: Sendable {
    func decode(_ data: Data, for request: ImageRequest) throws(ImageLoadingError) -> UIImage
}

typealias ImageLoadOperation = @Sendable (ImageRequest) async throws -> UIImage

struct ImageLoadJob: Sendable {
    let request: ImageRequest
    let priority: TaskPriority
    let operation: ImageLoadOperation
}

protocol ImageTaskDeduplicating: Sendable {
    func image(for job: ImageLoadJob) async throws -> UIImage
    func prefetch(_ job: ImageLoadJob)
    func cancelPrefetch(_ request: ImageRequest)
}
