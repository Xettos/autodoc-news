import Foundation

protocol NewsDateParsing: Sendable {
    func date(from string: String) -> Date?
}

struct NewsDateParser: NewsDateParsing {
    private static let styles: [Date.ISO8601FormatStyle] = [false, true].map(makeStyle(includingFraction:))

    init() {}

    func date(from string: String) -> Date? {
        Self.date(from: string)
    }

    static func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return styles.lazy.compactMap { try? $0.parse(trimmed) }.first
    }

    private static func makeStyle(includingFraction: Bool) -> Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZone: NewsTimeZone.moscow)
            .year().month().day()
            .dateTimeSeparator(.standard)
            .time(includingFractionalSeconds: includingFraction)
    }
}
