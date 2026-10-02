import Foundation

protocol HTMLEntityDecoding: Sendable {
    func decode(_ text: String) -> String
}

struct HTMLEntityDecoder: HTMLEntityDecoding {
    private typealias Entity = Constants.HTMLEntity

    init() {}

    func decode(_ text: String) -> String {
        guard text.contains(Entity.start) else { return text }

        var result = ""
        result.reserveCapacity(text.utf8.count)
        var index = text.startIndex
        while index < text.endIndex {
            let (character, next) = token(in: text, at: index)
            result.append(character)
            index = next
        }
        return result
    }

    private func token(in text: String, at index: String.Index) -> (Character, String.Index) {
        if text[index] == Entity.start, let entity = entity(in: text, at: index) {
            return entity
        }
        return (text[index], text.index(after: index))
    }

    private func entity(in text: String, at ampersand: String.Index) -> (Character, String.Index)? {
        let nameStart = text.index(after: ampersand)
        let searchWindow = text[nameStart...].prefix(Entity.maxNameLength + 1)
        guard let semicolon = searchWindow.firstIndex(of: Entity.end),
              let character = character(forEntityNamed: text[nameStart..<semicolon])
        else { return nil }
        return (character, text.index(after: semicolon))
    }

    private func character(forEntityNamed name: Substring) -> Character? {
        if let named = Entity.named[name] {
            return named
        }
        guard name.first == Entity.numericPrefix else { return nil }
        return numericCharacter(name.dropFirst())
    }

    private func numericCharacter(_ number: Substring) -> Character? {
        let codePoint = number.first.map(Entity.hexadecimalPrefixes.contains) == true
            ? UInt32(number.dropFirst(), radix: Entity.hexadecimalRadix)
            : UInt32(number)
        return codePoint.flatMap(Unicode.Scalar.init).map(Character.init)
    }
}
