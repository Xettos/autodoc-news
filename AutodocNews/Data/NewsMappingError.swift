import Foundation

enum NewsMappingError: Error, Equatable, Sendable {
    case missingPath
    case missingArticleBody
}

extension NewsMappingError: UserPresentableError {
    var userMessage: String {
        switch self {
        case .missingPath:
            Constants.Text.Mapping.missingPath
        case .missingArticleBody:
            Constants.Text.Mapping.missingArticleBody
        }
    }
}
