import Foundation

extension Constants {
    enum HTMLEntity {
        static let start: Character = "&"
        static let end: Character = ";"
        static let numericPrefix: Character = "#"
        static let hexadecimalPrefixes: Set<Character> = ["x", "X"]
        static let hexadecimalRadix = 16
        static let maxNameLength = 8

        static let named: [Substring: Character] = [
            "quot": "\"", "amp": "&", "lt": "<", "gt": ">", "apos": "'",
            "nbsp": "\u{00A0}", "laquo": "«", "raquo": "»",
            "mdash": "—", "ndash": "–", "hellip": "…",
            "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "bdquo": "„",
        ]
    }
}
