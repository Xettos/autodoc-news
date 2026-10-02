import UIKit

@MainActor
protocol NewsFeedRefreshControlling: AnyObject {
    func attach(to scrollView: UIScrollView)
    func makeRefreshKeyCommand(action: Selector) -> UIKeyCommand
    func refreshFromKeyCommand()
    func endRefreshingIfFinished(_ state: NewsFeedViewState)
}

@MainActor
final class NewsFeedRefreshController: NewsFeedRefreshControlling {
    private typealias Text = Constants.Feed.Text

    private let viewModel: any NewsFeedViewModelProtocol
    private let refreshControl = UIRefreshControl()

    init(viewModel: any NewsFeedViewModelProtocol) {
        self.viewModel = viewModel
    }

    func attach(to scrollView: UIScrollView) {
        scrollView.refreshControl = refreshControl
        refreshControl.addAction(UIAction { [weak self] _ in self?.handlePullToRefresh() }, for: .valueChanged)
    }

    func makeRefreshKeyCommand(action: Selector) -> UIKeyCommand {
        let command = UIKeyCommand(
            title: Text.refresh,
            action: action,
            input: Constants.Feed.KeyCommands.refreshInput,
            modifierFlags: .command
        )
        command.discoverabilityTitle = Text.refreshDiscoverabilityTitle
        return command
    }

    func refreshFromKeyCommand() {
        viewModel.refresh()
    }

    func endRefreshingIfFinished(_ state: NewsFeedViewState) {
        guard !state.isRefreshing, refreshControl.isRefreshing else { return }
        refreshControl.endRefreshing()
    }

    private func handlePullToRefresh() {
        viewModel.refresh()
        if !viewModel.state.isRefreshing {
            refreshControl.endRefreshing()
        }
    }
}
