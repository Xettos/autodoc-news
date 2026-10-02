import Foundation

enum NewsTimeZone {
    static let moscow = TimeZone(identifier: Constants.Formatting.timeZoneIdentifier) ?? moscowFixedOffset

    static let gregorianMoscow: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = moscow
        return calendar
    }()

    private static let moscowFixedOffset = TimeZone(
        secondsFromGMT: Constants.Formatting.fallbackUTCOffsetHours * Constants.Formatting.secondsPerHour
    ) ?? .gmt
}
