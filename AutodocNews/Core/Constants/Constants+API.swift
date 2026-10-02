import Foundation

extension Constants {
    enum API {
        static let baseURLString = "https://webapi.autodoc.ru/api/"
        static let pageSize = 15
        static let firstPage = 1

        static let requestTimeout: TimeInterval = 20
        static let resourceTimeout: TimeInterval = 45
        static let maxConnectionsPerHost = 4

        enum Path {
            static let news = "news"
            static let articleItem = "item"
            static let separator = "/"
        }
    }

    enum HTTP {
        static let acceptHeader = "Accept"
        static let jsonContentType = "application/json"
        static let successStatusCodes = 200..<300
    }
}
