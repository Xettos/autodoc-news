import UIKit

@MainActor
final class ArticleSkeletonView: UIView {
    private typealias Skeleton = Constants.Detail.Skeleton

    override init(frame: CGRect) {
        super.init(frame: frame)
        layoutParagraphs()
        configureAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func configureAccessibility() {
        isAccessibilityElement = true
        accessibilityLabel = Constants.Detail.Text.loadingAccessibilityLabel
    }

    private func layoutParagraphs() {
        let stackView = UIStackView(arrangedSubviews: Skeleton.paragraphLineWidths.map(makeParagraph))
        stackView.axis = .vertical
        stackView.spacing = Spacing.xl
        addSubviews(stackView)
        stackView.pinEdges(to: self)
    }

    private func makeParagraph(lineWidths: [CGFloat]) -> UIStackView {
        let paragraph = UIStackView()
        paragraph.axis = .vertical
        paragraph.alignment = .leading
        paragraph.spacing = Skeleton.lineSpacing
        lineWidths.forEach { addLine(widthFraction: $0, to: paragraph) }
        return paragraph
    }

    private func addLine(widthFraction: CGFloat, to paragraph: UIStackView) {
        let line = ShimmerView(cornerRadius: Skeleton.lineCornerRadius)
        paragraph.addArrangedSubview(line)
        NSLayoutConstraint.activate([
            line.heightAnchor.constraint(equalToConstant: Skeleton.lineHeight),
            line.widthAnchor.constraint(equalTo: paragraph.widthAnchor, multiplier: widthFraction)
        ])
    }
}
