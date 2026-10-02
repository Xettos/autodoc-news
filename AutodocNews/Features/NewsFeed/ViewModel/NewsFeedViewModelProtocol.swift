import Combine

@MainActor
protocol NewsFeedViewModelProtocol: AnyObject {
    var state: NewsFeedViewState { get }
    var statePublisher: AnyPublisher<NewsFeedViewState, Never> { get }
    var routes: AnyPublisher<NewsFeedRoute, Never> { get }
    var messages: AnyPublisher<String, Never> { get }

    func start()
    func refresh()
    func reload()
    func retryNextPage()
    func loadMoreIfNeeded(visibleIndex: Int)
    func selectItem(id: NewsItem.ID)

    func item(with id: NewsItem.ID) -> NewsItem?
    func viewData(for id: NewsItem.ID) -> NewsCardViewData?
}
