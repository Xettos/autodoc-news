import UIKit

final class BadgeLabel: UILabel {
    enum Style {
        case tinted
        case overlay

        fileprivate var textColor: UIColor {
            switch self {
            case .tinted: Palette.accent
            case .overlay: Palette.overlayText
            }
        }

        fileprivate var backgroundColor: UIColor {
            switch self {
            case .tinted: Palette.badgeBackground
            case .overlay: Palette.overlayBadgeBackground
            }
        }
    }

    private let contentInsets = NSDirectionalEdgeInsets(
        top: Spacing.xs,
        leading: Spacing.s,
        bottom: Spacing.xs,
        trailing: Spacing.s
    )

    private let style: Style

    init(style: Style = .tinted) {
        self.style = style
        super.init(frame: .zero)
        configureText()
        configureBackground()
        configureSizing()
        applyStyle()
        observeInterfaceStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let insets = contentInsets.resolved(for: effectiveUserInterfaceLayoutDirection)
        let textBounds = bounds.inset(by: insets)
        let textRect = super.textRect(forBounds: textBounds, limitedToNumberOfLines: numberOfLines)
        return textRect.inset(by: insets.negated)
    }

    override func drawText(in rect: CGRect) {
        let insets = contentInsets.resolved(for: effectiveUserInterfaceLayoutDirection)
        super.drawText(in: rect.inset(by: insets))
    }

    private func configureText() {
        font = Typography.badge
        adjustsFontForContentSizeCategory = true
        numberOfLines = 1
        lineBreakMode = .byTruncatingTail
    }

    private func configureBackground() {
        backgroundColor = nil
        isOpaque = false
        layer.cornerRadius = CornerRadius.badge
        layer.cornerCurve = .continuous
    }

    private func configureSizing() {
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func observeInterfaceStyle() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.updateBackgroundColor()
        }
    }

    private func applyStyle() {
        textColor = style.textColor
        updateBackgroundColor()
    }

    private func updateBackgroundColor() {
        layer.backgroundColor = style.backgroundColor.resolvedColor(with: traitCollection).cgColor
    }
}

private extension NSDirectionalEdgeInsets {
    func resolved(for direction: UIUserInterfaceLayoutDirection) -> UIEdgeInsets {
        let isRightToLeft = direction == .rightToLeft
        return UIEdgeInsets(
            top: top,
            left: isRightToLeft ? trailing : leading,
            bottom: bottom,
            right: isRightToLeft ? leading : trailing
        )
    }
}

private extension UIEdgeInsets {
    var negated: UIEdgeInsets {
        UIEdgeInsets(top: -top, left: -left, bottom: -bottom, right: -right)
    }
}
