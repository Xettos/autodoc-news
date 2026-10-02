import UIKit

@MainActor
enum NewsFeedUnavailableConfiguration {
    private typealias Text = Constants.Feed.Text

    private struct Content {
        let symbolName: String
        let title: String
        let message: String
        let buttonTitle: String
    }

    static func make(for phase: NewsFeedViewState.Phase, onReload: @escaping () -> Void) -> UIContentConfiguration? {
        switch phase {
        case .failed(let message): failure(message: message, onRetry: onReload)
        case .empty: empty(onReload: onReload)
        case .initialLoading, .content: nil
        }
    }

    static func failure(message: String, onRetry: @escaping () -> Void) -> UIContentUnavailableConfiguration {
        let content = Content(
            symbolName: Text.Symbol.failure,
            title: Text.failureTitle,
            message: message,
            buttonTitle: Text.retry
        )
        return make(content, action: onRetry)
    }

    static func empty(onReload: @escaping () -> Void) -> UIContentUnavailableConfiguration {
        let content = Content(
            symbolName: Text.Symbol.empty,
            title: Text.emptyTitle,
            message: Text.emptyMessage,
            buttonTitle: Text.refresh
        )
        return make(content, action: onReload)
    }

    private static func make(_ content: Content, action: @escaping () -> Void) -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: content.symbolName)
        configuration.text = content.title
        configuration.secondaryText = content.message
        configuration.button = makeButton(title: content.buttonTitle)
        configuration.buttonProperties.primaryAction = UIAction { _ in action() }
        configuration.background.backgroundColor = Palette.groupedBackground
        return configuration
    }

    private static func makeButton(title: String) -> UIButton.Configuration {
        var button = UIButton.Configuration.filled()
        button.title = title
        button.cornerStyle = .capsule
        return button
    }
}
