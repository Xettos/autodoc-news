import Combine
import UIKit

@MainActor
final class AppCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let moduleFactory: any NewsModuleFactory
    private var routeSubscription: AnyCancellable?

    var rootViewController: UIViewController { navigationController }

    init(navigationController: UINavigationController, moduleFactory: any NewsModuleFactory) {
        self.navigationController = navigationController
        self.moduleFactory = moduleFactory
        navigationController.navigationBar.prefersLargeTitles = true
    }

    func start() {
        let feed = moduleFactory.makeNewsFeedModule()
        subscribe(to: feed)
        navigationController.setViewControllers([feed.viewController], animated: false)
    }

    private func subscribe(to feed: NewsFeedModule) {
        routeSubscription = feed.routes
            .sink { [weak self, weak transitionSource = feed.transitionSource] route in
                self?.handle(route, from: transitionSource)
            }
    }

    private func handle(_ route: NewsFeedRoute, from transitionSource: (any NewsFeedTransitionSource)?) {
        switch route {
        case .article(let item):
            showArticle(item, from: transitionSource)
        }
    }

    private func showArticle(_ item: NewsItem, from transitionSource: (any NewsFeedTransitionSource)?) {
        let detail = moduleFactory.makeNewsDetailModule(for: item)
        if #available(iOS 18, *) {
            detail.preferredTransition = Self.zoomTransition(for: item.id, from: transitionSource)
        }
        navigationController.pushViewController(detail, animated: true)
    }

    @available(iOS 18, *)
    private static func zoomTransition(
        for itemID: NewsItem.ID,
        from transitionSource: (any NewsFeedTransitionSource)?
    ) -> UIViewController.Transition {
        let options = UIViewController.Transition.ZoomOptions()
        options.alignmentRectProvider = heroAlignmentRect(in:)
        return .zoom(options: options) { [weak transitionSource] _ in
            transitionSource?.transitionSourceView(for: itemID)
        }
    }

    @available(iOS 18, *)
    private static func heroAlignmentRect(in context: UIViewController.Transition.ZoomOptions.AlignmentRectContext) -> CGRect? {
        guard
            let detail = context.zoomedViewController as? any ZoomTransitionDestination & UIViewController,
            let heroView = detail.heroView
        else { return nil }
        return heroView.convert(heroView.bounds, to: detail.view)
    }
}
