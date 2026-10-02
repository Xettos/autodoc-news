import UIKit

@MainActor
final class NewsCardTextArea {
    let guide = UILayoutGuide()
    private lazy var heightConstraint = guide.heightAnchor.constraint(equalToConstant: 0)

    func install(in contentView: UIView, below imageView: UIView) {
        contentView.addLayoutGuide(guide)
        activateGuideConstraints(in: contentView)
        activateImageConstraints(imageView, in: contentView)
    }

    func updateHeight(for traitCollection: UITraitCollection) {
        heightConstraint.constant = NewsCardMetrics.metrics(for: traitCollection).textBlockHeight
    }

    private func activateGuideConstraints(in contentView: UIView) {
        let insets = Constants.Feed.Layout.Card.textInsets
        NSLayoutConstraint.activate([
            guide.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: insets.leading),
            guide.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -insets.trailing),
            guide.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            heightConstraint
        ])
    }

    private func activateImageConstraints(_ imageView: UIView, in contentView: UIView) {
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: guide.topAnchor)
        ])
    }
}
