import UIKit

extension UIView {
    func addReadableColumn(maximumWidth: CGFloat) -> UILayoutGuide {
        let column = UILayoutGuide()
        addLayoutGuide(column)
        NSLayoutConstraint.activate(readableColumnConstraints(for: column, maximumWidth: maximumWidth))
        return column
    }

    private func readableColumnConstraints(for column: UILayoutGuide, maximumWidth: CGFloat) -> [NSLayoutConstraint] {
        let readable = readableContentGuide
        let preferredWidth = column.widthAnchor.constraint(equalTo: readable.widthAnchor)
        preferredWidth.priority = .defaultHigh
        return [
            column.topAnchor.constraint(equalTo: readable.topAnchor),
            column.bottomAnchor.constraint(equalTo: readable.bottomAnchor),
            column.centerXAnchor.constraint(equalTo: readable.centerXAnchor),
            column.widthAnchor.constraint(lessThanOrEqualTo: readable.widthAnchor),
            column.widthAnchor.constraint(lessThanOrEqualToConstant: maximumWidth),
            preferredWidth
        ]
    }
}
