import UIKit

@MainActor
enum NewsItemDrag {
    static func items(for item: NewsItem) -> [UIDragItem] {
        guard let url = item.webURL else { return [] }
        let itemProvider = NSItemProvider(object: url as NSURL)
        itemProvider.suggestedName = item.title
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item.id
        return [dragItem]
    }
}
