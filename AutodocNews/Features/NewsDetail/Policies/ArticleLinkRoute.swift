import Foundation

enum ArticleLinkRoute: Equatable, Sendable {
    case safari
    case system
    case ignored

    init(url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        if Constants.Detail.Web.safariSchemes.contains(scheme) {
            self = .safari
        } else if Constants.Detail.Web.systemSchemes.contains(scheme) {
            self = .system
        } else {
            self = .ignored
        }
    }
}
