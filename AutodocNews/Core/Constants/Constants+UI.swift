import CoreGraphics
import Foundation

extension Constants {
    enum UI {
        enum ColorAsset {
            static let accent = "AccentColor"
        }

        enum Alpha {
            static let overlayBadge: CGFloat = 0.45
            static let badgeTintDark: CGFloat = 0.22
            static let badgeTintLight: CGFloat = 0.12
        }

        enum Shimmer {
            static let animationKey = "shimmer"
            static let animatedKeyPath = "locations"
            static let duration: CFTimeInterval = 1.4
            static let startLocations: [NSNumber] = [-1, -0.5, 0]
            static let endLocations: [NSNumber] = [1, 1.5, 2]
            static let startPoint = CGPoint(x: 0, y: 0.5)
            static let endPoint = CGPoint(x: 1, y: 0.5)
        }

        enum Scrim {
            static let alphas: [CGFloat] = [0, 0.3, 0.7]
            static let locations: [NSNumber] = [0, 0.5, 1]
            static let startPoint = CGPoint(x: 0.5, y: 0)
            static let endPoint = CGPoint(x: 0.5, y: 1)
        }
    }
}
