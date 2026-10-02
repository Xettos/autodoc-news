import Combine

@MainActor
protocol NewsDetailViewModelProtocol: AnyObject {
    var header: NewsDetailHeaderViewData { get }
    var bodyStatePublisher: AnyPublisher<NewsDetailBodyState, Never> { get }

    func load()
    func retry()
}
