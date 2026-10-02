import UIKit

extension AppDependencies {
    func makeNewsFeedModule() -> NewsFeedModule {
        let viewModel = makeNewsFeedViewModel()
        let dependencies = makeNewsFeedViewDependencies(viewModel: viewModel)
        let viewController = NewsFeedViewController(viewModel: viewModel, dependencies: dependencies)
        return NewsFeedModule(viewController: viewController, transitionSource: viewController, routes: viewModel.routes)
    }

    private func makeNewsFeedViewModel() -> NewsFeedViewModel {
        let dependencies = NewsFeedViewModel.Dependencies(
            repository: newsRepository,
            viewDataMapper: NewsCardViewDataMapper(dateFormatter: dateFormatter),
            pagingTrigger: NewsFeedPagingTrigger(threshold: Constants.Feed.Pagination.nextPageThreshold),
            errorMessages: errorMessageMapper
        )
        return NewsFeedViewModel(dependencies: dependencies, pageSize: Constants.API.pageSize)
    }

    private func makeNewsFeedViewDependencies(
        viewModel: any NewsFeedViewModelProtocol
    ) -> NewsFeedViewController.Dependencies {
        let layoutProvider = NewsFeedLayoutProvider()
        let services = NewsFeedViewComponentsFactory.Services(
            imageLoader: imageLoader,
            snapshotBuilder: NewsFeedSnapshotBuilder(),
            imageRequestFactory: NewsFeedImageRequestFactory(layoutProvider: layoutProvider),
            imagePrefetcher: NewsFeedImagePrefetcher(imageLoader: imageLoader),
            itemMenuProvider: NewsFeedItemMenuProvider(sharePresenter: sharePresenter, urlOpener: urlOpener)
        )
        return NewsFeedViewController.Dependencies(
            layoutProvider: layoutProvider,
            components: NewsFeedViewComponentsFactory(viewModel: viewModel, services: services),
            notificationCenter: .default
        )
    }
}
