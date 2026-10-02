import Foundation
import Testing
import UIKit
@testable import AutodocNews

@Suite("ImageMemoryCache")
struct ImageMemoryCacheTests {
    private enum TestData {
        static let costLimit = 64 * 1024 * 1024
        static let url = URL(filePath: "/news/cached.jpg")
        static let otherURL = URL(filePath: "/news/other.jpg")
        static let smallSize = CGSize(width: 100, height: 100)
        static let largeSize = CGSize(width: 400, height: 400)
        static let scale: CGFloat = 1
    }

    private let notificationCenter = NotificationCenter()
    private let cache: ImageMemoryCache

    init() {
        cache = ImageMemoryCache(costLimit: TestData.costLimit, notificationCenter: notificationCenter)
    }

    @Test("an image is found again under an equal request")
    func keyRoundTrip() {
        let image = UIImage()
        cache.insert(image, for: request(size: TestData.smallSize))

        #expect(cache.image(for: request(size: TestData.smallSize)) === image)
    }

    @Test("a different target size of the same URL is a different entry")
    func sizeIsPartOfTheKey() {
        cache.insert(UIImage(), for: request(size: TestData.smallSize))

        #expect(cache.image(for: request(size: TestData.largeSize)) == nil)
    }

    @Test("the largest cached variant of a URL is returned for it")
    func largestVariant() {
        let large = UIImage()
        cache.insert(large, for: request(size: TestData.largeSize))
        cache.insert(UIImage(), for: request(size: TestData.smallSize))

        #expect(cache.largestImage(for: TestData.url) === large)
    }

    @Test("the original image counts as larger than any thumbnail")
    func originalIsLargest() {
        let original = UIImage()
        cache.insert(UIImage(), for: request(size: TestData.largeSize))
        cache.insert(original, for: ImageRequest(url: TestData.url))

        #expect(cache.largestImage(for: TestData.url) === original)
    }

    @Test("a URL with nothing cached has no largest variant")
    func largestVariantMiss() {
        cache.insert(UIImage(), for: request(size: TestData.smallSize))

        #expect(cache.largestImage(for: TestData.otherURL) == nil)
    }

    @Test("a memory warning empties the cache and its size index")
    func memoryWarningPurges() {
        cache.insert(UIImage(), for: request(size: TestData.smallSize))

        notificationCenter.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)

        #expect(cache.image(for: request(size: TestData.smallSize)) == nil)
        #expect(cache.largestImage(for: TestData.url) == nil)
    }

    private func request(size: CGSize) -> ImageRequest {
        ImageRequest(url: TestData.url, targetSize: size, scale: TestData.scale)
    }
}
