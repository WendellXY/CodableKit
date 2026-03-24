//
//  JSONValue.swift
//  CodableKit
//
//  Created by Assistant on 2026/3/24.
//

/// A dynamic JSON tree value similar to Rust's `serde_json::Value`.
///
/// Use `JSONValue` when the schema is only partially known or when a payload
/// intentionally carries arbitrary nested JSON content.
public enum JSONValue: Codable, Equatable, Hashable, Sendable {
  case null
  case bool(Bool)
  case string(String)
  case int(Int)
  case double(Double)
  case array([JSONValue])
  case object([String: JSONValue])

  public var isNull: Bool {
    if case .null = self {
      return true
    }
    return false
  }

  public var boolValue: Bool? {
    if case .bool(let value) = self {
      return value
    }
    return nil
  }

  public var stringValue: String? {
    if case .string(let value) = self {
      return value
    }
    return nil
  }

  public var intValue: Int? {
    if case .int(let value) = self {
      return value
    }
    return nil
  }

  public var doubleValue: Double? {
    if case .double(let value) = self {
      return value
    }
    return nil
  }

  public var arrayValue: [JSONValue]? {
    if case .array(let value) = self {
      return value
    }
    return nil
  }

  public var objectValue: [String: JSONValue]? {
    if case .object(let value) = self {
      return value
    }
    return nil
  }

  public subscript(key: String) -> JSONValue? {
    objectValue?[key]
  }

  public subscript(index: Int) -> JSONValue? {
    guard case .array(let values) = self, values.indices.contains(index) else {
      return nil
    }
    return values[index]
  }

  public init(from decoder: any Decoder) throws {
    if let objectContainer = try? decoder.container(keyedBy: JSONValueCodingKey.self) {
      var object: [String: JSONValue] = [:]
      object.reserveCapacity(objectContainer.allKeys.count)
      for key in objectContainer.allKeys {
        object[key.stringValue] = try objectContainer.decode(JSONValue.self, forKey: key)
      }
      self = .object(object)
      return
    }

    if var arrayContainer = try? decoder.unkeyedContainer() {
      var array: [JSONValue] = []
      if let count = arrayContainer.count {
        array.reserveCapacity(count)
      }
      while !arrayContainer.isAtEnd {
        array.append(try arrayContainer.decode(JSONValue.self))
      }
      self = .array(array)
      return
    }

    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .int(value)
    } else if let value = try? container.decode(Double.self) {
      self = .double(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unsupported JSON value"
      )
    }
  }

  public func encode(to encoder: any Encoder) throws {
    switch self {
    case .null:
      var container = encoder.singleValueContainer()
      try container.encodeNil()

    case .bool(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)

    case .string(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)

    case .int(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)

    case .double(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)

    case .array(let values):
      var container = encoder.unkeyedContainer()
      for value in values {
        try container.encode(value)
      }

    case .object(let values):
      var container = encoder.container(keyedBy: JSONValueCodingKey.self)
      for (key, value) in values {
        try container.encode(value, forKey: JSONValueCodingKey(key))
      }
    }
  }
}

extension JSONValue: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) {
    self = .null
  }
}

extension JSONValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .bool(value)
  }
}

extension JSONValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .string(value)
  }
}

extension JSONValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self = .int(value)
  }
}

extension JSONValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self = .double(value)
  }
}

extension JSONValue: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: JSONValue...) {
    self = .array(elements)
  }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, JSONValue)...) {
    self = .object(Dictionary(uniqueKeysWithValues: elements))
  }
}

private struct JSONValueCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(_ stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}
