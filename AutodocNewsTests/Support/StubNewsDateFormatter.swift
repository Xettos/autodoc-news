import Foundation
@testable import AutodocNews

struct StubNewsDateFormatter: NewsDateFormatting {
    var output = "DATE"

    func string(from date: Date) -> String {
        output
    }
}
