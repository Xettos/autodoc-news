import ImageIO
import UIKit

struct ImageDecoder: ImageDecoding {
    private static let primaryImageIndex = 0

    init() {}

    func decode(_ data: Data, for request: ImageRequest) throws(ImageLoadingError) -> UIImage {
        let source = try makeSource(from: data)
        let thumbnail = try makeThumbnail(from: source, for: request)
        return preparedForDisplay(UIImage(cgImage: thumbnail))
    }

    private func makeSource(from data: Data) throws(ImageLoadingError) -> CGImageSource {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            throw .decodingFailed
        }
        return source
    }

    private func makeThumbnail(from source: CGImageSource, for request: ImageRequest) throws(ImageLoadingError) -> CGImage {
        let maxPixelSize = thumbnailMaxPixelSize(for: request.targetPixelSize, sourceSize: orientedPixelSize(of: source))
        let options = thumbnailOptions(maxPixelSize: maxPixelSize)
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, Self.primaryImageIndex, options) else {
            throw .decodingFailed
        }
        return thumbnail
    }

    private func preparedForDisplay(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let isNativeFormat = cgImage.colorSpace?.model == .rgb && cgImage.bitsPerComponent == Constants.ImageLoading.nativeBitsPerComponent
        return isNativeFormat ? image : image.preparingForDisplay() ?? image
    }

    private func thumbnailOptions(maxPixelSize: Int?) -> CFDictionary {
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        if let maxPixelSize {
            options[kCGImageSourceThumbnailMaxPixelSize] = maxPixelSize
        }
        return options as CFDictionary
    }

    private func thumbnailMaxPixelSize(for target: ImageRequest.PixelSize?, sourceSize: CGSize?) -> Int? {
        guard let target else { return nil }
        guard let sourceSize, sourceSize.width > 0, sourceSize.height > 0 else {
            return max(target.width, target.height)
        }
        let fillScale = max(CGFloat(target.width) / sourceSize.width, CGFloat(target.height) / sourceSize.height)
        guard fillScale < 1 else { return nil }
        return Int((max(sourceSize.width, sourceSize.height) * fillScale).rounded(.up))
    }

    private func orientedPixelSize(of source: CGImageSource) -> CGSize? {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, Self.primaryImageIndex, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? CGImagePropertyOrientation.up.rawValue
        let isTransposed = Constants.ImageLoading.transposedEXIFOrientations.contains(orientation)
        return isTransposed ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }
}
