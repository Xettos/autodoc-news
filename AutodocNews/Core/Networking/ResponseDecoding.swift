import Foundation

protocol ResponseDecoding: Sendable {
    func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value
}

extension JSONDecoder: ResponseDecoding {}
