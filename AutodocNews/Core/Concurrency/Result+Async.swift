import Foundation

extension Result where Failure == any Error {
    init(
        isolation: isolated (any Actor)? = #isolation,
        catching body: () async throws -> Success
    ) async {
        do {
            self = .success(try await body())
        } catch {
            self = .failure(error)
        }
    }
}
