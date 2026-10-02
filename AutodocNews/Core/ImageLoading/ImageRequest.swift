import CoreGraphics
import Foundation

struct ImageRequest: Hashable, Sendable {
    let url: URL
    let targetPixelSize: PixelSize?

    init(url: URL) {
        self.url = url
        self.targetPixelSize = nil
    }

    init(url: URL, targetSize: CGSize, scale: CGFloat) {
        self.url = url
        self.targetPixelSize = PixelSize(bucketing: targetSize, scale: scale)
    }

    var maxPixelSize: Int? {
        targetPixelSize.map { max($0.width, $0.height) }
    }
}

extension ImageRequest {
    struct PixelSize: Hashable, Sendable {
        let width: Int
        let height: Int

        var area: Int { width * height }
    }
}

extension ImageRequest.PixelSize {
    init?(bucketing size: CGSize, scale: CGFloat) {
        let width = size.width * scale
        let height = size.height * scale
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
        self.init(width: Self.roundedUpToBucket(width), height: Self.roundedUpToBucket(height))
    }

    private static func roundedUpToBucket(_ value: CGFloat) -> Int {
        let step = Constants.ImageLoading.pixelBucketStep
        let bucketed = (min(value, Constants.ImageLoading.maxPixelSide) / step).rounded(.up) * step
        return Int(bucketed)
    }
}
