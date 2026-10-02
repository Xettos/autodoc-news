import Foundation

protocol NewsDateFormatting: Sendable {
    func string(from date: Date) -> String
}

struct NewsDateFormatter: NewsDateFormatting {
    private static let style = Date.VerbatimFormatStyle(
        format: Constants.Formatting.publishedDateFormat,
        locale: Locale(identifier: Constants.Formatting.localeIdentifier),
        timeZone: NewsTimeZone.moscow,
        calendar: NewsTimeZone.gregorianMoscow
    )

    init() {}

    func string(from date: Date) -> String {
        Self.style.format(date)
    }
}
