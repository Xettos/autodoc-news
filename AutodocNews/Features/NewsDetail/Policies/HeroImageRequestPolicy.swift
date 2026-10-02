import Foundation

protocol HeroImageRequestDeciding: Sendable {
    func shouldReplace(
        current: ImageRequest?,
        displayedPixelSize: ImageRequest.PixelSize?,
        with request: ImageRequest
    ) -> Bool
}

struct HeroImageRequestPolicy: HeroImageRequestDeciding {
    func shouldReplace(
        current: ImageRequest?,
        displayedPixelSize: ImageRequest.PixelSize?,
        with request: ImageRequest
    ) -> Bool {
        guard let current else { return true }
        guard request != current, let target = request.targetPixelSize else { return false }
        return !Self.size(current.targetPixelSize, covers: target)
            && !Self.size(displayedPixelSize, covers: target)
    }

    private static func size(_ size: ImageRequest.PixelSize?, covers target: ImageRequest.PixelSize) -> Bool {
        guard let size else { return false }
        return target.width <= size.width && target.height <= size.height
    }
}
