import UIKit

@MainActor
enum CardHighlight {
    private typealias Animation = Constants.Feed.Animation

    static func apply(_ isHighlighted: Bool, to view: UIView) {
        let transform = isHighlighted ? pressedTransform : .identity
        guard view.transform != transform else { return }
        UIView.animate(
            withDuration: Animation.highlightDuration,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            view.transform = transform
        }
    }

    private static let pressedTransform = CGAffineTransform(
        scaleX: Animation.pressedScale,
        y: Animation.pressedScale
    )
}
