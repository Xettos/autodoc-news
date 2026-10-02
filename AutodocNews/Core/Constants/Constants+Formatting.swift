import Foundation

extension Constants {
    enum Formatting {
        static let timeZoneIdentifier = "Europe/Moscow"
        static let fallbackUTCOffsetHours = 3
        static let secondsPerHour = 3600
        static let localeIdentifier = "ru_RU"
        static let publishedDateFormat: Date.FormatString = "\(day: .defaultDigits) \(month: .wide) \(year: .defaultDigits)"
    }
}
