import UIKit

@MainActor
final class AppDependencies {
    lazy var newsRepository: any NewsRepository = makeNewsRepository()
    lazy var imageLoader: any ImageLoading = makeImageLoader()
    let dateFormatter: any NewsDateFormatting = NewsDateFormatter()
    let errorMessageMapper: any ErrorMessageMapping = ErrorMessageMapper()
    let sharePresenter: any SharePresenting = SharePresenter()

    var urlOpener: any URLOpening { UIApplication.shared }
}

extension AppDependencies: CoordinatorFactory {
    func makeAppCoordinator() -> any Coordinator {
        AppCoordinator(navigationController: UINavigationController(), moduleFactory: self)
    }
}

extension AppDependencies: NewsModuleFactory {}
