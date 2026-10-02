import CoreGraphics
import Foundation

extension Constants {
    enum ImageLoading {
        static let physicalMemoryDivisor: UInt64 = 32
        static let memoryCostCap = 128 * bytesPerMegabyte

        static let urlCacheMemoryCapacity = 4 * bytesPerMegabyte
        static let urlCacheDiskCapacity = 256 * bytesPerMegabyte
        static let urlCacheDirectoryName = "ImagePipeline"

        static let requestTimeout: TimeInterval = 10
        static let resourceTimeout: TimeInterval = 60
        static let maxConnectionsPerHost = 6

        static let transientRetryCount = 1
        static let transientRetryDelay: Duration = .milliseconds(500)
        static let transientErrorCodes: Set<URLError.Code> = [.timedOut, .networkConnectionLost]

        static let maxConcurrentDecodes = 2

        static let pixelBucketStep: CGFloat = 128
        static let maxPixelSide: CGFloat = 8192

        static let nativeBitsPerComponent = 8
        static let transposedEXIFOrientations: ClosedRange<UInt32> = 5...8

        static let fadeDuration: CFTimeInterval = 0.2
        static let fadeAnimationKey = "RemoteImageView.fade"
        static let failureSymbolName = "photo"

        private static let bytesPerMegabyte = 1024 * 1024
    }
}
