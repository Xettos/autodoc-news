import UIKit

protocol ImageLoading: AnyObject, Sendable {
    func cachedImage(for request: ImageRequest) -> UIImage?
    func cachedImage(forURL url: URL) -> UIImage?
    func image(for request: ImageRequest) async throws -> UIImage
    func prefetch(_ requests: [ImageRequest])
    func cancelPrefetch(_ requests: [ImageRequest])
}
