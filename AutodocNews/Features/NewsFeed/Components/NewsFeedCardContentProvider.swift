import Foundation

@MainActor
protocol NewsFeedCardContentProviding {
    func cardContent(for itemID: NewsItem.ID, in slot: @autoclosure () -> NewsCardImageSlot?) -> NewsCardContent?
}

struct NewsFeedCardContentProvider: NewsFeedCardContentProviding {
    private let viewModel: any NewsFeedViewModelProtocol
    private let imageRequestFactory: any NewsFeedImageRequestMaking

    init(viewModel: any NewsFeedViewModelProtocol, imageRequestFactory: any NewsFeedImageRequestMaking) {
        self.viewModel = viewModel
        self.imageRequestFactory = imageRequestFactory
    }

    func cardContent(for itemID: NewsItem.ID, in slot: @autoclosure () -> NewsCardImageSlot?) -> NewsCardContent? {
        guard let viewData = viewModel.viewData(for: itemID) else { return nil }
        return NewsCardContent(viewData: viewData, imageRequest: imageRequest(for: viewData, in: slot))
    }

    private func imageRequest(for viewData: NewsCardViewData, in slot: () -> NewsCardImageSlot?) -> ImageRequest? {
        guard let url = viewData.imageURL, let slot = slot() else { return nil }
        return imageRequestFactory.imageRequest(for: url, in: slot)
    }
}
