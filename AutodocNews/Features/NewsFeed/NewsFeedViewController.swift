import Combine
import UIKit

@MainActor
final class NewsFeedViewController: UIViewController {
    private let viewModel: any NewsFeedViewModelProtocol
    private let dependencies: Dependencies
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private lazy var contentRenderer = dependencies.components.makeContentRenderer(for: collectionView)
    private lazy var interactions = dependencies.components.makeInteractions(locator: contentRenderer, presenter: self)
    private lazy var refreshController = dependencies.components.makeRefreshController()
    private let messageBanner = NewsFeedMessageBanner()
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: any NewsFeedViewModelProtocol, dependencies: Dependencies) {
        self.viewModel = viewModel
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationItem()
        configureCollectionView()
        messageBanner.place(in: view)
        addKeyCommand(refreshController.makeRefreshKeyCommand(action: #selector(handleRefreshKeyCommand)))
        bindViewModel()
        observeAppActivation()
        viewModel.start()
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.contentRenderer.reconfigureVisibleNews()
        }
    }

    override func updateContentUnavailableConfiguration(using state: UIContentUnavailableConfigurationState) {
        contentUnavailableConfiguration = NewsFeedUnavailableConfiguration.make(for: viewModel.state.phase) { [weak self] in
            self?.viewModel.reload()
        }
    }

    func transitionSourceView(for itemID: NewsItem.ID) -> UIView? {
        guard isViewLoaded else { return nil }
        return contentRenderer.cell(for: itemID)?.transitionSourceView
    }

    private func configureNavigationItem() {
        title = Constants.Feed.Text.screenTitle
        navigationItem.largeTitleDisplayMode = .always
    }

    private func configureCollectionView() {
        configureCollectionViewAppearance()
        assignCollectionViewDelegates()
        refreshController.attach(to: collectionView)
        layoutCollectionView()
        observeContentSizeCategory()
    }

    private func configureCollectionViewAppearance() {
        view.backgroundColor = Palette.groupedBackground
        collectionView.backgroundColor = Palette.groupedBackground
        collectionView.alwaysBounceVertical = true
    }

    private func assignCollectionViewDelegates() {
        collectionView.delegate = interactions
        collectionView.prefetchDataSource = interactions
        collectionView.dragDelegate = interactions
    }

    private func layoutCollectionView() {
        view.addSubviews(collectionView)
        collectionView.pinEdges(to: view)
    }

    private func observeContentSizeCategory() {
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _: UITraitCollection) in
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.contentRenderer.reconfigureVisibleNews()
        }
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        dependencies.layoutProvider.makeLayout { [weak self] sectionIndex in
            self?.contentRenderer.sectionIdentifier(for: sectionIndex)
        }
    }

    private func bindViewModel() {
        bindState()
        bindMessages()
    }

    private func bindState() {
        viewModel.statePublisher
            .removeDuplicates()
            .transitions()
            .sink { [weak self] transition in self?.render(transition) }
            .store(in: &cancellables)
    }

    private func bindMessages() {
        viewModel.messages
            .sink { [weak self] message in self?.messageBanner.show(message) }
            .store(in: &cancellables)
    }

    private func observeAppActivation() {
        dependencies.notificationCenter
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.contentRenderer.reconfigureVisibleNews() }
            .store(in: &cancellables)
    }

    private func render(_ transition: NewsFeedStateTransition) {
        refreshController.endRefreshingIfFinished(transition.current)
        guard transition.changesContent else { return }
        contentRenderer.apply(transition)
        if transition.changesPhase {
            setNeedsUpdateContentUnavailableConfiguration()
        }
    }

    @objc private func handleRefreshKeyCommand() {
        refreshController.refreshFromKeyCommand()
    }
}
