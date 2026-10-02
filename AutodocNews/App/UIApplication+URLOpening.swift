import UIKit

extension UIApplication: URLOpening {
    func open(url: URL) {
        open(url, options: [:], completionHandler: nil)
    }
}
