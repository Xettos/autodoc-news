import Combine
import UIKit

@MainActor
protocol NewsModuleFactory {
    func makeNewsFeedModule() -> NewsFeedModule
    func makeNewsDetailModule(for item: NewsItem) -> UIViewController
}

struct NewsFeedModule {
    let viewController: UIViewController
    let transitionSource: any NewsFeedTransitionSource
    let routes: AnyPublisher<NewsFeedRoute, Never>
}

@MainActor
protocol NewsFeedTransitionSource: AnyObject {
    func transitionSourceView(for itemID: NewsItem.ID) -> UIView?
}

@MainActor
protocol ZoomTransitionDestination: AnyObject {
    var heroView: UIView? { get }
}

extension NewsFeedViewController: NewsFeedTransitionSource {}
extension NewsDetailViewController: ZoomTransitionDestination {}
