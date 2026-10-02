import UIKit

extension AppDependencies {
    func makeNewsDetailModule(for item: NewsItem) -> UIViewController {
        NewsDetailViewController(
            viewModel: makeNewsDetailViewModel(for: item),
            headerView: NewsDetailHeaderView(imageLoader: imageLoader, heroRequestPolicy: HeroImageRequestPolicy()),
            bodyView: makeArticleBodyView(),
            urlOpener: urlOpener,
            sharePresenter: sharePresenter
        )
    }

    private func makeNewsDetailViewModel(for item: NewsItem) -> NewsDetailViewModel {
        NewsDetailViewModel(
            item: item,
            repository: newsRepository,
            dateFormatter: dateFormatter,
            errorMessageMapper: errorMessageMapper
        )
    }

    private func makeArticleBodyView() -> ArticleBodyView {
        ArticleBodyView(
            articleRenderer: ArticleHTMLRenderer(cleaner: ArticleHTMLCleaner(), documentBuilder: ArticleHTMLDocumentBuilder()),
            navigationPolicy: ArticleNavigationPolicy(documentURL: Constants.Detail.Web.baseURL)
        )
    }
}
