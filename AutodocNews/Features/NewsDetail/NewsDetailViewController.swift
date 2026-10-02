import Combine
import SafariServices
import UIKit

@MainActor
final class NewsDetailViewController: UIViewController {
    private typealias Text = Constants.Detail.Text
    private typealias Symbol = Constants.Detail.Symbol

    private let viewModel: any NewsDetailViewModelProtocol
    private let headerView: any NewsDetailHeaderDisplaying
    private let bodyView: any ArticleBodyDisplaying
    private let urlOpener: any URLOpening
    private let sharePresenter: any SharePresenting
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private lazy var readableColumn = view.addReadableColumn(maximumWidth: Constants.Detail.Layout.maxColumnWidth)
    private var cancellables: Set<AnyCancellable> = []
    private var isTitleInNavigationBar = false

    init(
        viewModel: any NewsDetailViewModelProtocol,
        headerView: any NewsDetailHeaderDisplaying,
        bodyView: any ArticleBodyDisplaying,
        urlOpener: any URLOpening,
        sharePresenter: any SharePresenting
    ) {
        self.viewModel = viewModel
        self.headerView = headerView
        self.bodyView = bodyView
        self.urlOpener = urlOpener
        self.sharePresenter = sharePresenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.background
        configureNavigationItem()
        configureLayout()
        bindViewModel()
        viewModel.load()
    }

    var heroView: UIView? {
        headerView.heroView
    }

    private func bindViewModel() {
        headerView.configure(with: viewModel.header)
        bindBodyActions()
        observeBodyState()
    }

    private func bindBodyActions() {
        bodyView.onRetry = { [weak self] in
            self?.viewModel.retry()
        }
        bodyView.onOpenLink = { [weak self] url in
            self?.open(url)
        }
    }

    private func observeBodyState() {
        viewModel.bodyStatePublisher
            .removeDuplicates()
            .sink { [weak self] state in
                self?.render(state)
            }
            .store(in: &cancellables)
    }

    private func render(_ state: NewsDetailBodyState) {
        switch state {
        case .loading:
            bodyView.showLoading()
        case .failed(let message):
            bodyView.showError(message: message)
        case .loaded(let content):
            bodyView.showArticle(content)
        }
    }

    private func configureLayout() {
        setupScrollView()
        setupContentView()
        layoutHeader()
        layoutBody()
    }

    private func setupScrollView() {
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        view.addSubviews(scrollView)
        scrollView.pinEdges(to: view)
    }

    private func setupContentView() {
        scrollView.addSubviews(contentView)
        let contentGuide = scrollView.contentLayoutGuide
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func layoutHeader() {
        contentView.addSubviews(headerView)
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        headerView.alignContent(to: readableColumn)
    }

    private func layoutBody() {
        contentView.addSubviews(bodyView)
        NSLayoutConstraint.activate([
            bodyView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: Spacing.xl),
            bodyView.leadingAnchor.constraint(equalTo: readableColumn.leadingAnchor),
            bodyView.trailingAnchor.constraint(equalTo: readableColumn.trailingAnchor),
            bodyView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.xxl)
        ])
    }

    private func configureNavigationItem() {
        navigationItem.largeTitleDisplayMode = .never
        guard let webURL = viewModel.header.webURL else { return }
        navigationItem.rightBarButtonItems = [makeShareItem(for: webURL), makeSafariItem(for: webURL)]
    }

    private func makeShareItem(for url: URL) -> UIBarButtonItem {
        let shareItem = UIBarButtonItem()
        shareItem.primaryAction = UIAction(
            title: Text.share,
            image: UIImage(systemName: Symbol.share)
        ) { [weak self, weak shareItem] _ in
            guard let self, let shareItem else { return }
            sharePresenter.presentShareSheet(for: url, anchor: .barItem(shareItem), from: self)
        }
        return shareItem
    }

    private func makeSafariItem(for url: URL) -> UIBarButtonItem {
        UIBarButtonItem(primaryAction: UIAction(
            title: Text.openInSafari,
            image: UIImage(systemName: Symbol.safari)
        ) { [weak self] _ in
            self?.open(url)
        })
    }

    private func updateNavigationTitle() {
        let isTitleHidden = headerView.titleMaxY(in: scrollView) < visibleContentTop
        guard isTitleHidden != isTitleInNavigationBar else { return }
        isTitleInNavigationBar = isTitleHidden
        navigationItem.title = isTitleHidden ? viewModel.header.title : nil
    }

    private var visibleContentTop: CGFloat {
        scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    }

    private func open(_ url: URL) {
        switch ArticleLinkRoute(url: url) {
        case .safari:
            presentSafari(with: url)
        case .system:
            urlOpener.open(url: url)
        case .ignored:
            break
        }
    }

    private func presentSafari(with url: URL) {
        let safariController = SFSafariViewController(url: url)
        safariController.preferredControlTintColor = Palette.accent
        present(safariController, animated: true)
    }
}

extension NewsDetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateNavigationTitle()
    }
}
