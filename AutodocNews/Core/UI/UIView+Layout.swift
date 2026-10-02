import UIKit

@MainActor
protocol LayoutAnchorProviding {
    var leadingAnchor: NSLayoutXAxisAnchor { get }
    var trailingAnchor: NSLayoutXAxisAnchor { get }
    var topAnchor: NSLayoutYAxisAnchor { get }
    var bottomAnchor: NSLayoutYAxisAnchor { get }
}

extension UIView: LayoutAnchorProviding {}
extension UILayoutGuide: LayoutAnchorProviding {}

extension UIView {
    func addSubviews(_ views: UIView...) {
        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
    }

    @discardableResult
    func pinEdges(
        to target: LayoutAnchorProviding,
        insets: NSDirectionalEdgeInsets = .zero
    ) -> [NSLayoutConstraint] {
        translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            leadingAnchor.constraint(equalTo: target.leadingAnchor, constant: insets.leading),
            trailingAnchor.constraint(equalTo: target.trailingAnchor, constant: -insets.trailing),
            topAnchor.constraint(equalTo: target.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: target.bottomAnchor, constant: -insets.bottom)
        ]
        NSLayoutConstraint.activate(constraints)
        return constraints
    }
}
