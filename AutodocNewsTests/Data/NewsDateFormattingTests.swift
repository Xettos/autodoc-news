import Foundation
import Testing
@testable import AutodocNews

@Suite("News date parsing and formatting")
struct NewsDateFormattingTests {
    private let parser: any NewsDateParsing = NewsDateParser()
    private let formatter: any NewsDateFormatting = NewsDateFormatter()

    @Test("API timestamps without a zone are read as Moscow time", arguments: [
        ("2026-08-17T00:00:00", "2026-08-16T21:00:00Z"),
        ("2026-01-01T03:00:00", "2026-01-01T00:00:00Z"),
        ("  2026-08-17T12:30:45\n", "2026-08-17T09:30:45Z"),
    ])
    func parsesMoscowTime(apiValue: String, utcValue: String) throws {
        #expect(parser.date(from: apiValue) == (try Date.utc(utcValue)))
    }

    @Test("fractional seconds are accepted")
    func parsesFractionalSeconds() throws {
        let date = try #require(parser.date(from: "2026-08-17T10:30:00.250"))

        let expected = try Date.utc("2026-08-17T07:30:00.250Z")
        #expect(abs(date.timeIntervalSince(expected)) < 0.001)
    }

    @Test("garbage input yields nil", arguments: ["", "   ", "вчера", "17.08.2026", "2026-13-45T00:00:00"])
    func rejectsGarbage(apiValue: String) {
        #expect(parser.date(from: apiValue) == nil)
    }

    @Test("formats as a Russian long date without the «г.» suffix")
    func formatsRussianDate() throws {
        let date = try #require(parser.date(from: "2026-08-17T00:00:00"))

        #expect(formatter.string(from: date) == "17 августа 2026")
    }

    @Test("day does not shift for instants that are still the previous day in UTC")
    func formatsInMoscowTimeZone() throws {
        let lateEveningUTC = try Date.utc("2026-08-16T22:30:00Z")

        #expect(formatter.string(from: lateEveningUTC) == "17 августа 2026")
    }
}
