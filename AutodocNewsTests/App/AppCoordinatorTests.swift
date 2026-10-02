import Combine
import Testing
import UIKit
@testable import AutodocNews

@MainActor
@Suite("AppCoordinator")
struct AppCoordinatorTests {
    private enum TestData {
        static let item = NewsItem.fixture(id: 7)
    }

    private let navigationController = UINavigationController()
    private let factory = StubNewsModuleFactory()
    private let coordinator: AppCoordinator

    init() {
        coordinator = AppCoordinator(navigationController: navigationController, moduleFactory: factory)
    }

    @Test("the navigation controller is the root and shows large titles")
    func rootIsNavigationController() {
        #expect(coordinator.rootViewController === navigationController)
        #expect(navigationController.navigationBar.prefersLargeTitles)
    }

    @Test("start installs the feed as the only screen")
    func startInstallsFeed() {
        coordinator.start()

        #expect(navigationController.viewControllers == [factory.feedViewController])
    }

    @Test("an article route pushes the detail screen built for that item")
    func articleRoutePushesDetail() {
        coordinator.start()

        factory.routes.send(.article(TestData.item))

        #expect(factory.requestedDetailItems == [TestData.item])
        #expect(navigationController.viewControllers.last === factory.detailViewController)
    }

    @Test("the pushed detail screen zooms out of the feed card")
    func detailUsesZoomTransition() {
        guard #available(iOS 18, *) else { return }
        coordinator.start()

        factory.routes.send(.article(TestData.item))

        #expect(factory.detailViewController.preferredTransition != nil)
    }

    @Test("the coordinator does not keep the feed's transition source alive")
    func transitionSourceIsNotRetained() {
        weak let transitionSource = factory.makeTransitionSource()
        coordinator.start()

        factory.releaseTransitionSource()

        #expect(transitionSource == nil)
    }
}

@MainActor
private final class StubNewsModuleFactory: NewsModuleFactory {
    let feedViewController = UIViewController()
    let detailViewController = UIViewController()
    let routes = PassthroughSubject<NewsFeedRoute, Never>()
    private(set) var requestedDetailItems: [NewsItem] = []
    private var transitionSource: StubTransitionSource?

    func makeTransitionSource() -> StubTransitionSource {
        let source = StubTransitionSource()
        transitionSource = source
        return source
    }

    func releaseTransitionSource() {
        transitionSource = nil
    }

    func makeNewsFeedModule() -> NewsFeedModule {
        NewsFeedModule(
            viewController: feedViewController,
            transitionSource: transitionSource ?? makeTransitionSource(),
            routes: routes.eraseToAnyPublisher()
        )
    }

    func makeNewsDetailModule(for item: NewsItem) -> UIViewController {
        requestedDetailItems.append(item)
        return detailViewController
    }
}

@MainActor
private final class StubTransitionSource: NewsFeedTransitionSource {
    func transitionSourceView(for itemID: NewsItem.ID) -> UIView? {
        nil
    }
}
