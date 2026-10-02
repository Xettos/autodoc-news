import UIKit

@MainActor
final class RemoteImageView: UIImageView {
    var placeholderColor: UIColor = Palette.imagePlaceholder {
        didSet {
            if image == nil { backgroundColor = placeholderColor }
        }
    }

    private var currentRequest: ImageRequest?
    private(set) var loadTask: Task<Void, Never>?
    private var failureIconView: UIImageView?
    private let failureIconArea = UILayoutGuide()
    private var failureIconAreaBottom: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        layoutFailureIconArea()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        loadTask?.cancel()
    }

    func setImage(_ request: ImageRequest?, using loader: any ImageLoading) {
        guard !isShowingOrLoading(request) else { return }
        cancelLoading()
        guard let request else { return }
        currentRequest = request
        showOrLoad(request, using: loader)
    }

    func placeFailureIcon(above anchor: NSLayoutYAxisAnchor) {
        failureIconAreaBottom?.isActive = false
        let bottomConstraint = failureIconArea.bottomAnchor.constraint(equalTo: anchor)
        bottomConstraint.isActive = true
        failureIconAreaBottom = bottomConstraint
    }

    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        currentRequest = nil
        layer.removeAnimation(forKey: Constants.ImageLoading.fadeAnimationKey)
        image = nil
        backgroundColor = placeholderColor
        hideFailureIcon()
    }

    private func configureAppearance() {
        contentMode = .scaleAspectFill
        clipsToBounds = true
        backgroundColor = placeholderColor
    }

    private func isShowingOrLoading(_ request: ImageRequest?) -> Bool {
        guard let request, request == currentRequest else { return false }
        return image != nil || loadTask != nil
    }

    private func showOrLoad(_ request: ImageRequest, using loader: any ImageLoading) {
        if let cached = loader.cachedImage(for: request) {
            show(cached)
            return
        }
        if let interim = loader.cachedImage(forURL: request.url) {
            show(interim)
        }
        startLoading(request, using: loader)
    }

    private func startLoading(_ request: ImageRequest, using loader: any ImageLoading) {
        loadTask = Task { [weak self] in
            let result = await Result { try await loader.image(for: request) }
            guard !Task.isCancelled else { return }
            self?.finishLoading(with: result, for: request)
        }
    }

    private func finishLoading(with result: Result<UIImage, any Error>, for request: ImageRequest) {
        guard request == currentRequest else { return }
        loadTask = nil
        switch result {
        case .success(let loadedImage):
            reveal(loadedImage)
        case .failure:
            showFailureIconIfEmpty()
        }
    }

    private func reveal(_ loadedImage: UIImage) {
        if shouldAnimateAppearance {
            addFadeTransition()
        }
        show(loadedImage)
    }

    private var shouldAnimateAppearance: Bool {
        window != nil && !UIAccessibility.isReduceMotionEnabled
    }

    private func show(_ loadedImage: UIImage) {
        hideFailureIcon()
        image = loadedImage
        backgroundColor = nil
    }

    private func addFadeTransition() {
        let transition = CATransition()
        transition.type = .fade
        transition.duration = Constants.ImageLoading.fadeDuration
        transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(transition, forKey: Constants.ImageLoading.fadeAnimationKey)
    }

    private func showFailureIconIfEmpty() {
        guard image == nil else { return }
        let iconView = failureIconView ?? makeFailureIconView()
        failureIconView = iconView
        iconView.isHidden = false
        clipsToBounds = false
    }

    private func hideFailureIcon() {
        failureIconView?.isHidden = true
        clipsToBounds = true
    }

    private func makeFailureIconView() -> UIImageView {
        let configuration = UIImage.SymbolConfiguration(textStyle: .title2)
        let symbol = UIImage(systemName: Constants.ImageLoading.failureSymbolName, withConfiguration: configuration)
        let iconView = UIImageView(image: symbol)
        iconView.tintColor = Palette.tertiaryText
        iconView.contentMode = .scaleAspectFit
        layoutFailureIcon(iconView)
        return iconView
    }

    private func layoutFailureIconArea() {
        addLayoutGuide(failureIconArea)
        let bottomConstraint = failureIconArea.bottomAnchor.constraint(equalTo: bottomAnchor)
        failureIconAreaBottom = bottomConstraint
        NSLayoutConstraint.activate([
            failureIconArea.topAnchor.constraint(equalTo: topAnchor),
            failureIconArea.leadingAnchor.constraint(equalTo: leadingAnchor),
            failureIconArea.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomConstraint
        ])
    }

    private func layoutFailureIcon(_ iconView: UIImageView) {
        addSubviews(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: failureIconArea.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: failureIconArea.centerYAnchor),
            iconView.heightAnchor.constraint(lessThanOrEqualTo: failureIconArea.heightAnchor)
        ])
    }
}
