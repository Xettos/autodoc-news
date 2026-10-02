import os
import UIKit

final class ImageMemoryCache: ImageMemoryCaching, @unchecked Sendable {
    private let storage = Storage()
    private let largestRequestByURL = OSAllocatedUnfairLock(initialState: [URL: ImageRequest]())
    private let notificationCenter: NotificationCenter
    private let memoryWarningObserver: any NSObjectProtocol

    init(costLimit: Int, notificationCenter: NotificationCenter) {
        storage.totalCostLimit = costLimit
        self.notificationCenter = notificationCenter
        memoryWarningObserver = Self.observeMemoryWarnings(in: notificationCenter) { [storage, largestRequestByURL] in
            storage.removeAllObjects()
            largestRequestByURL.withLock { $0.removeAll() }
        }
    }

    deinit {
        notificationCenter.removeObserver(memoryWarningObserver)
    }

    func image(for request: ImageRequest) -> UIImage? {
        storage.object(forKey: Key(request))
    }

    func largestImage(for url: URL) -> UIImage? {
        guard let request = largestRequestByURL.withLock({ $0[url] }) else { return nil }
        guard let image = image(for: request) else {
            forgetEvicted(request)
            return nil
        }
        return image
    }

    func insert(_ image: UIImage, for request: ImageRequest) {
        storage.setObject(image, forKey: Key(request), cost: Self.decodedByteCount(of: image))
        indexIfLargest(request)
    }

    private func indexIfLargest(_ request: ImageRequest) {
        largestRequestByURL.withLock { index in
            if let current = index[request.url], Self.pixelArea(of: current) >= Self.pixelArea(of: request) {
                return
            }
            index[request.url] = request
        }
    }

    private func forgetEvicted(_ request: ImageRequest) {
        largestRequestByURL.withLock { index in
            guard index[request.url] == request else { return }
            index[request.url] = nil
        }
    }

    private static func pixelArea(of request: ImageRequest) -> Int {
        request.targetPixelSize?.area ?? .max
    }

    private static func observeMemoryWarnings(
        in notificationCenter: NotificationCenter,
        purge: @escaping @Sendable () -> Void
    ) -> any NSObjectProtocol {
        notificationCenter.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { _ in
            purge()
        }
    }

    private static func decodedByteCount(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

private extension ImageMemoryCache {
    final class Storage: NSCache<Key, UIImage>, @unchecked Sendable {}

    final class Key: NSObject {
        private let request: ImageRequest
        private let precomputedHash: Int

        init(_ request: ImageRequest) {
            self.request = request
            self.precomputedHash = request.hashValue
        }

        override var hash: Int { precomputedHash }

        override func isEqual(_ object: Any?) -> Bool {
            (object as? Key)?.request == request
        }
    }
}
