import UIKit

@MainActor
enum PopoverAnchor {
    case view(UIView)
    case barItem(UIBarButtonItem)
}

@MainActor
protocol SharePresenting {
    func presentShareSheet(for url: URL, anchor: PopoverAnchor, from presenter: UIViewController)
}

struct SharePresenter: SharePresenting {
    init() {}

    func presentShareSheet(for url: URL, anchor: PopoverAnchor, from presenter: UIViewController) {
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityController.popoverPresentationController {
            attach(popover, to: anchor)
        }
        presenter.present(activityController, animated: true)
    }

    private func attach(_ popover: UIPopoverPresentationController, to anchor: PopoverAnchor) {
        switch anchor {
        case .view(let sourceView):
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        case .barItem(let barItem):
            popover.sourceItem = barItem
        }
    }
}
