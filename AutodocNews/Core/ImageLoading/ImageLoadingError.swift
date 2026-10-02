import Foundation

enum ImageLoadingError: Error, Equatable, Sendable, HTTPResponseFailure {
    case invalidResponse
    case httpStatus(Int)
    case emptyData
    case decodingFailed
    case transport(URLError.Code)
}
