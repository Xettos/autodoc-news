import Foundation

protocol UserPresentableError: LocalizedError {
    var userMessage: String { get }
}

extension UserPresentableError {
    var errorDescription: String? { userMessage }
}

protocol ErrorMessageMapping: Sendable {
    func message(for error: any Error) -> String
}

struct ErrorMessageMapper: ErrorMessageMapping {
    init() {}

    func message(for error: any Error) -> String {
        if let presentable = error as? any UserPresentableError {
            return presentable.userMessage
        }
        return NetworkError(error).userMessage
    }
}
