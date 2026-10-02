import Foundation

protocol ArticleHTMLCleaning: Sendable {
    func cleanUp(_ fragment: String, removingImageAt imageURL: URL?) -> String
}

struct ArticleHTMLCleaner: ArticleHTMLCleaning {
    private typealias Patterns = Constants.Detail.Cleaner

    private static let cleanupRegexes: [NSRegularExpression] = [
        Patterns.emptyBlockPattern,
        Patterns.leadingLineBreaksPattern,
        Patterns.trailingLineBreaksPattern
    ].compactMap(makeRegex)

    func cleanUp(_ fragment: String, removingImageAt imageURL: URL?) -> String {
        let html = NSMutableString(string: fragment)
        Self.regexes(removingImageAt: imageURL).forEach { $0.removeMatches(in: html) }
        return html as String
    }

    private static func regexes(removingImageAt imageURL: URL?) -> [NSRegularExpression] {
        guard let heroRegex = imageURL.flatMap(heroImageRegex(for:)) else { return cleanupRegexes }
        return [heroRegex] + cleanupRegexes
    }

    private static func heroImageRegex(for url: URL) -> NSRegularExpression? {
        let source = Patterns.imageSourcePattern(address: addressPattern(for: url))
        let image = Patterns.imagePattern(source: source)
        return makeRegex(Patterns.linkedImagePattern(image: image))
    }

    private static func addressPattern(for url: URL) -> String {
        let escapedAddress = NSRegularExpression.escapedPattern(for: schemelessAddress(of: url))
            .replacingOccurrences(of: Patterns.ampersand, with: Patterns.ampersandPattern)
        return Patterns.optionalHTTPSchemePattern + escapedAddress
    }

    private static func schemelessAddress(of url: URL) -> String {
        let absolute = url.absoluteString
        guard let separator = absolute.range(of: Patterns.schemeSeparator) else { return absolute }
        return String(absolute[separator.lowerBound...])
    }

    private static func makeRegex(_ pattern: String) -> NSRegularExpression? {
        do {
            return try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            assertionFailure("\(Constants.Detail.Log.invalidPattern) \(pattern): \(error)")
            return nil
        }
    }
}

private extension NSRegularExpression {
    func removeMatches(in string: NSMutableString) {
        let range = NSRange(location: 0, length: string.length)
        _ = replaceMatches(in: string, range: range, withTemplate: "")
    }
}
