import Foundation

enum NetworkError: Error, Equatable, HTTPResponseFailure {
    case offline
    case timedOut
    case invalidResponse
    case httpStatus(Int)
    case decoding(codingPath: String)
    case transport(URLError.Code)

    init(_ error: any Error) {
        if let networkError = error as? NetworkError {
            self = networkError
        } else if let urlError = error as? URLError {
            self = NetworkError(urlErrorCode: urlError.code)
        } else if let decodingError = error as? DecodingError {
            self = .decoding(codingPath: decodingError.codingPathDescription)
        } else {
            self = .transport(.unknown)
        }
    }

    private init(urlErrorCode: URLError.Code) {
        switch urlErrorCode {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            self = .offline
        case .timedOut:
            self = .timedOut
        default:
            self = .transport(urlErrorCode)
        }
    }
}

extension NetworkError: UserPresentableError {
    var userMessage: String {
        switch self {
        case .offline:
            Constants.Text.Network.offline
        case .timedOut:
            Constants.Text.Network.timedOut
        case .invalidResponse, .decoding:
            Constants.Text.Network.unreadableResponse
        case .httpStatus(let code):
            Constants.Text.Network.httpStatus(code)
        case .transport:
            Constants.Text.Network.transport
        }
    }
}

private extension DecodingError {
    var codingPathDescription: String {
        context?.codingPath
            .map { $0.intValue.map(String.init) ?? $0.stringValue }
            .joined(separator: Constants.App.Diagnostics.codingPathSeparator) ?? ""
    }

    var context: Context? {
        switch self {
        case .typeMismatch(_, let context), .valueNotFound(_, let context),
             .keyNotFound(_, let context), .dataCorrupted(let context):
            context
        @unknown default:
            nil
        }
    }
}
