import UIKit

final class ShimmerView: UIView {
    private typealias Animation = Constants.UI.Shimmer

    override class var layerClass: AnyClass { CAGradientLayer.self }

    private var gradientLayer: CAGradientLayer { unsafeDowncast(layer, to: CAGradientLayer.self) }

    init(cornerRadius: CGFloat = CornerRadius.badge) {
        super.init(frame: .zero)
        configureLayer(cornerRadius: cornerRadius)
        updateColors()
        disableInteraction()
        observeInterfaceStyle()
        observeReduceMotion()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateAnimationState()
    }

    private var shouldAnimate: Bool {
        window != nil && !UIAccessibility.isReduceMotionEnabled
    }

    private func disableInteraction() {
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    private func observeInterfaceStyle() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.updateColors()
        }
    }

    private func observeReduceMotion() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionStatusDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    private func configureLayer(cornerRadius: CGFloat) {
        gradientLayer.startPoint = Animation.startPoint
        gradientLayer.endPoint = Animation.endPoint
        gradientLayer.locations = Animation.startLocations
        gradientLayer.cornerRadius = cornerRadius
        gradientLayer.cornerCurve = .continuous
    }

    private func updateColors() {
        let base = Palette.skeletonBase.resolvedColor(with: traitCollection).cgColor
        let highlight = Palette.skeletonHighlight.resolvedColor(with: traitCollection).cgColor
        gradientLayer.colors = [base, highlight, base]
    }

    private func updateAnimationState() {
        if shouldAnimate {
            startAnimationIfNeeded()
        } else {
            gradientLayer.removeAnimation(forKey: Animation.animationKey)
        }
    }

    private func startAnimationIfNeeded() {
        guard gradientLayer.animation(forKey: Animation.animationKey) == nil else { return }
        gradientLayer.add(makeSweepAnimation(), forKey: Animation.animationKey)
    }

    private func makeSweepAnimation() -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: Animation.animatedKeyPath)
        animation.fromValue = Animation.startLocations
        animation.toValue = Animation.endLocations
        animation.duration = Animation.duration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.timeOffset = CACurrentMediaTime().truncatingRemainder(dividingBy: Animation.duration)
        animation.isRemovedOnCompletion = false
        return animation
    }

    @objc private func reduceMotionStatusDidChange() {
        updateAnimationState()
    }
}
