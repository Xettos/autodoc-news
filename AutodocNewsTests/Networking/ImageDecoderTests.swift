import Foundation
import ImageIO
import Testing
import UIKit
@testable import AutodocNews

@Suite("ImageDecoder")
struct ImageDecoderTests {
    private enum TestData {
        static let url = URL(filePath: "/news/decoded.jpg")
        static let sourceWidth = 512
        static let sourceHeight = 256
        static let smallTarget = ImageRequest.PixelSize(width: 128, height: 128)
        static let largeTarget = ImageRequest.PixelSize(width: 1024, height: 1024)
        static let invalidData = Data("not an image".utf8)
    }

    private let decoder = ImageDecoder()

    @Test("a smaller target is downsampled just enough to cover it in aspect fill")
    func downsamplesToCoverTarget() throws {
        let data = try TestImageData.jpeg(width: TestData.sourceWidth, height: TestData.sourceHeight)

        let image = try decoder.decode(data, for: request(TestData.smallTarget))

        #expect(try pixelSize(of: image) == size(TestData.sourceWidth / 2, TestData.sourceHeight / 2))
    }

    @Test("a target larger than the source never upscales")
    func neverUpscales() throws {
        let data = try TestImageData.jpeg(width: TestData.sourceWidth, height: TestData.sourceHeight)

        let image = try decoder.decode(data, for: request(TestData.largeTarget))

        #expect(try pixelSize(of: image) == size(TestData.sourceWidth, TestData.sourceHeight))
    }

    @Test("a request without a target size decodes the original")
    func decodesOriginal() throws {
        let data = try TestImageData.jpeg(width: TestData.sourceWidth, height: TestData.sourceHeight)

        let image = try decoder.decode(data, for: ImageRequest(url: TestData.url))

        #expect(try pixelSize(of: image) == size(TestData.sourceWidth, TestData.sourceHeight))
    }

    @Test("a quarter-turn EXIF orientation is applied to the pixels", arguments: [
        CGImagePropertyOrientation.right, .left, .rightMirrored, .leftMirrored,
    ])
    func appliesTransposingOrientation(orientation: CGImagePropertyOrientation) throws {
        let data = try TestImageData.jpeg(width: TestData.sourceWidth, height: TestData.sourceHeight, orientation: orientation)

        let image = try decoder.decode(data, for: ImageRequest(url: TestData.url))

        #expect(try pixelSize(of: image) == size(TestData.sourceHeight, TestData.sourceWidth))
    }

    @Test("downsampling measures the source after its EXIF orientation")
    func downsamplesOrientedSource() throws {
        let data = try TestImageData.jpeg(width: TestData.sourceWidth, height: TestData.sourceHeight, orientation: .right)

        let image = try decoder.decode(data, for: request(TestData.smallTarget))

        #expect(try pixelSize(of: image) == size(TestData.sourceHeight / 2, TestData.sourceWidth / 2))
    }

    @Test("a half-turn EXIF orientation keeps the stored dimensions")
    func keepsDimensionsForHalfTurn() throws {
        let data = try TestImageData.jpeg(width: TestData.sourceWidth, height: TestData.sourceHeight, orientation: .down)

        let image = try decoder.decode(data, for: ImageRequest(url: TestData.url))

        #expect(try pixelSize(of: image) == size(TestData.sourceWidth, TestData.sourceHeight))
    }

    @Test("data that is not an image throws decodingFailed", arguments: [TestData.invalidData, Data()])
    func invalidDataThrows(data: Data) {
        #expect(throws: ImageLoadingError.decodingFailed) {
            try decoder.decode(data, for: ImageRequest(url: TestData.url))
        }
    }

    private func request(_ target: ImageRequest.PixelSize) -> ImageRequest {
        ImageRequest(url: TestData.url, targetSize: CGSize(width: target.width, height: target.height), scale: 1)
    }

    private func size(_ width: Int, _ height: Int) -> ImageRequest.PixelSize {
        ImageRequest.PixelSize(width: width, height: height)
    }

    private func pixelSize(of image: UIImage) throws -> ImageRequest.PixelSize {
        let cgImage = try #require(image.cgImage)
        return ImageRequest.PixelSize(width: cgImage.width, height: cgImage.height)
    }
}
