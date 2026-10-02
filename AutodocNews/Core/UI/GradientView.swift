import UIKit

final class GradientView: UIView {
    private typealias Scrim = Constants.UI.Scrim

    override class var layerClass: AnyClass { CAGradientLayer.self }

    private var gradientLayer: CAGradientLayer { unsafeDowncast(layer, to: CAGradientLayer.self) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        configureBottomScrim()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func configureBottomScrim() {
        gradientLayer.colors = Scrim.alphas.map { UIColor.black.withAlphaComponent($0).cgColor }
        gradientLayer.locations = Scrim.locations
        gradientLayer.startPoint = Scrim.startPoint
        gradientLayer.endPoint = Scrim.endPoint
    }
}
