//
//  LossyDictionary.swift
//  CodableKit
//
//  Created by Assistant on 2025/9/6.
//

import Foundation

/// A wrapper that decodes a dictionary in a "lossy" way:
/// - Skips entries whose value fails to decode
/// - Skips keys that cannot be converted to the expected `Key` type
///
/// Notes:
/// - JSON object keys are strings. This wrapper requires `Key` to be
///   `LosslessStringConvertible` so keys can be constructed from the raw
///   JSON string key. Typical keys like `String` and `Int` are supported.
public struct LossyDictionary<Key, Value>: Decodable where Key: LosslessStringConvertible & Hashable, Value: Decodable {
  public var elements: [Key: Value] = [:]

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: AnyCodingKey.self)
    var result: [Key: Value] = [:]
    for codingKey in container.allKeys {
      guard let key = Key(codingKey.stringValue) else { continue }
      do {
        let value = try container.decode(Value.self, forKey: codingKey)
        result[key] = value
      } catch {
        // Skip invalid values
        continue
      }
    }
    self.elements = result
  }

  private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) {
      self.stringValue = stringValue
      self.intValue = Int(stringValue)
    }
    init?(intValue: Int) {
      self.intValue = intValue
      self.stringValue = String(intValue)
    }
  }
}

extension LossyDictionary: Sendable where Key: Sendable, Value: Sendable {}
extension LossyDictionary: Equatable where Value: Equatable {}
extension LossyDictionary: Hashable where Value: Hashable {}

extension LossyDictionary: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (Key, Value)...) {
    self.elements = Dictionary(uniqueKeysWithValues: elements)
  }
}

extension LossyDictionary: CustomStringConvertible {
  public var description: String {
    let pairs = elements.map { "\($0): \($1)" }.joined(separator: ", ")
    return "LossyDictionary(\(pairs))"
  }
}

extension LossyDictionary: CustomDebugStringConvertible {
  public var debugDescription: String { description }
}
