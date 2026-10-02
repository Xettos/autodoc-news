import CoreGraphics
import Foundation
import Testing
@testable import AutodocNews

@Suite("ImageRequest bucketing")
struct ImageRequestTests {
    private let url: URL

    init() throws {
        url = try #require(URL(string: "https://file.autodoc.ru/news/image.jpg"))
    }

    @Test("close sizes fall into the same cache key")
    func closeSizesShareKey() {
        let prefetch = ImageRequest(url: url, targetSize: CGSize(width: 358, height: 201), scale: 3)
        let display = ImageRequest(url: url, targetSize: CGSize(width: 358.5, height: 201.4), scale: 3)

        #expect(prefetch == display)
        #expect(prefetch.hashValue == display.hashValue)
    }

    @Test("pixel size is rounded up to a multiple of the bucket step (128)")
    func roundsUpToBucket() {
        let request = ImageRequest(url: url, targetSize: CGSize(width: 100, height: 50), scale: 2)

        #expect(request.targetPixelSize == ImageRequest.PixelSize(width: 256, height: 128))
        #expect(request.maxPixelSize == 256)
    }

    @Test("sizes are capped at the maximum pixel side")
    func capsHugeSizes() {
        let request = ImageRequest(url: url, targetSize: CGSize(width: 10_000, height: 100), scale: 3)

        #expect(request.maxPixelSize == Int(Constants.ImageLoading.maxPixelSide))
    }

    @Test("invalid target size requests the original image", arguments: [
        CGSize.zero,
        CGSize(width: 100, height: 0),
        CGSize(width: -10, height: 50),
        CGSize(width: CGFloat.infinity, height: 50),
        CGSize(width: CGFloat.nan, height: 50),
    ])
    func invalidSizeFallsBackToOriginal(size: CGSize) {
        let request = ImageRequest(url: url, targetSize: size, scale: 3)

        #expect(request == ImageRequest(url: url))
        #expect(request.maxPixelSize == nil)
    }
}
