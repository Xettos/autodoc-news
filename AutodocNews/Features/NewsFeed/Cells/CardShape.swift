import UIKit

@MainActor
enum CardShape {
    static func applyCardBackground(to view: UIView) {
        view.backgroundColor = Palette.cardBackground
        applyCorners(to: view)
    }

    static func applyCorners(to view: UIView, maskedCorners: CACornerMask = allCorners) {
        view.layer.cornerRadius = CornerRadius.card
        view.layer.cornerCurve = .continuous
        view.layer.maskedCorners = maskedCorners
    }

    static func hoverStyle() -> UIHoverStyle {
        UIHoverStyle(effect: .lift, shape: .rect(cornerRadius: CornerRadius.card))
    }

    static func targetedPreview(for view: UIView) -> UITargetedPreview {
        let parameters = UIPreviewParameters()
        parameters.visiblePath = path(for: view)
        parameters.backgroundColor = .clear
        return UITargetedPreview(view: view, parameters: parameters)
    }

    static func dragPreviewParameters(for view: UIView) -> UIDragPreviewParameters {
        let parameters = UIDragPreviewParameters()
        parameters.visiblePath = path(for: view)
        return parameters
    }

    static let topCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    static let bottomCorners: CACornerMask = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    static let allCorners: CACornerMask = topCorners.union(bottomCorners)

    private static func path(for view: UIView) -> UIBezierPath {
        UIBezierPath(roundedRect: view.bounds, cornerRadius: CornerRadius.card)
    }
}
