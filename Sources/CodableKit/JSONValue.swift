//
//  JSONValue.swift
//  CodableKit
//
//  Created by Assistant on 2026/3/24.
//

import Foundation

/// Errors produced by `JSONValue` convenience APIs that work with JSON text.
public enum JSONValueError: Error, Equatable, Sendable {
  /// The provided or generated string could not be represented as UTF-8 data.
  case invalidUTF8String
}

/// A typed path component used to traverse nested `JSONValue` trees.
///
/// Use string keys for objects and integer indexes for arrays:
///
/// ```swift
/// let name = value[path: ["user", "profile", "name"]]?.stringValue
/// let firstFlag = value[path: ["user", "flags", 0]]?.boolValue
/// ```
public enum JSONPathComponent: Hashable, Sendable {
  /// Addresses an object member by key.
  case key(String)

  /// Addresses an array element by zero-based index.
  case index(Int)
}

extension JSONPathComponent: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .key(value)
  }
}

extension JSONPathComponent: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self = .index(value)
  }
}

/// A dynamic JSON tree value similar to Rust's `serde_json::Value`.
///
/// Use `JSONValue` when the schema is only partially known or when a payload
/// intentionally carries arbitrary nested JSON content.
///
/// `JSONValue` can be decoded from standard `JSONDecoder` pipelines, built
/// directly from Swift literals, and traversed with keyed, indexed, or path-
/// based lookups.
public enum JSONValue: Codable, Equatable, Hashable, Sendable {
  /// A JSON `null`.
  case null

  /// A JSON boolean.
  case bool(Bool)

  /// A JSON string.
  case string(String)

  /// A JSON integer that decoded losslessly as `Int`.
  case int(Int)

  /// A JSON number that required floating-point representation.
  case double(Double)

  /// A JSON array containing nested `JSONValue` elements.
  case array([JSONValue])

  /// A JSON object containing string-keyed nested `JSONValue` members.
  case object([String: JSONValue])

  /// Decodes a top-level JSON payload from raw UTF-8 data.
  ///
  /// - Parameter jsonData: The raw JSON payload.
  /// - Throws: Any error thrown by `JSONDecoder`.
  public init(jsonData: Data) throws {
    self = try JSONDecoder().decode(Self.self, from: jsonData)
  }

  /// Decodes a top-level JSON payload from a JSON string.
  ///
  /// - Parameter jsonString: A string containing JSON text.
  /// - Throws: `JSONValueError.invalidUTF8String` when the string cannot be
  ///   converted to UTF-8, or any error thrown by `JSONDecoder`.
  public init(jsonString: String) throws {
    guard let data = jsonString.data(using: .utf8) else {
      throw JSONValueError.invalidUTF8String
    }
    try self.init(jsonData: data)
  }

  /// Returns `true` when the value is `.null`.
  public var isNull: Bool {
    if case .null = self {
      return true
    }
    return false
  }

  /// Returns the underlying boolean when the value is `.bool`.
  public var boolValue: Bool? {
    if case .bool(let value) = self {
      return value
    }
    return nil
  }

  /// Returns the underlying string when the value is `.string`.
  public var stringValue: String? {
    if case .string(let value) = self {
      return value
    }
    return nil
  }

  /// Returns the underlying integer when the value is `.int`.
  public var intValue: Int? {
    if case .int(let value) = self {
      return value
    }
    return nil
  }

  /// Returns the underlying floating-point number when the value is `.double`.
  public var doubleValue: Double? {
    if case .double(let value) = self {
      return value
    }
    return nil
  }

  /// Returns the underlying array when the value is `.array`.
  public var arrayValue: [JSONValue]? {
    if case .array(let value) = self {
      return value
    }
    return nil
  }

  /// Returns the underlying object when the value is `.object`.
  public var objectValue: [String: JSONValue]? {
    if case .object(let value) = self {
      return value
    }
    return nil
  }

  /// Returns the object member for `key` when the value is `.object`.
  public subscript(key: String) -> JSONValue? {
    objectValue?[key]
  }

  /// Returns the array element for `index` when the value is `.array`.
  public subscript(index: Int) -> JSONValue? {
    guard case .array(let values) = self, values.indices.contains(index) else {
      return nil
    }
    return values[index]
  }

  /// Traverses the value using a sequence of object keys and array indexes.
  ///
  /// - Parameter components: The path to follow from the current node.
  /// - Returns: The nested value if every path component resolves successfully.
  public subscript(path components: [JSONPathComponent]) -> JSONValue? {
    var current: JSONValue? = self
    for component in components {
      guard let value = current else { return nil }
      switch component {
      case .key(let key):
        current = value[key]
      case .index(let index):
        current = value[index]
      }
    }
    return current
  }

  /// Encodes the value as JSON data.
  ///
  /// - Parameter prettyPrinted: When `true`, the output uses pretty-printed
  ///   formatting for easier inspection.
  /// - Throws: Any error thrown by `JSONEncoder`.
  public func jsonData(prettyPrinted: Bool = false) throws -> Data {
    let encoder = JSONEncoder()
    if prettyPrinted {
      encoder.outputFormatting = [.prettyPrinted]
    }
    return try encoder.encode(self)
  }

  /// Encodes the value as a UTF-8 JSON string.
  ///
  /// - Parameter prettyPrinted: When `true`, the output uses pretty-printed
  ///   formatting for easier inspection.
  /// - Throws: Any error thrown by `JSONEncoder`, or
  ///   `JSONValueError.invalidUTF8String` if the encoded data cannot be
  ///   represented as UTF-8.
  public func jsonString(prettyPrinted: Bool = false) throws -> String {
    let data = try jsonData(prettyPrinted: prettyPrinted)
    guard let string = String(data: data, encoding: .utf8) else {
      throw JSONValueError.invalidUTF8String
    }
    return string
  }

  /// Decodes a JSON value from the decoder's current container.
  ///
  /// The decoding order matches the structure exposed by `Decoder`:
  /// keyed container, then unkeyed container, then scalar probing.
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

  /// Encodes the value back into the matching JSON container or scalar form.
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

/// Allows `nil` to construct `.null`.
extension JSONValue: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) {
    self = .null
  }
}

/// Allows boolean literals like `true` and `false`.
extension JSONValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .bool(value)
  }
}

/// Allows string literals like `"hello"`.
extension JSONValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .string(value)
  }
}

/// Allows integer literals like `42`.
extension JSONValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self = .int(value)
  }
}

/// Allows floating-point literals like `3.14`.
extension JSONValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self = .double(value)
  }
}

/// Allows array literals like `[1, "two", nil]`.
extension JSONValue: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: JSONValue...) {
    self = .array(elements)
  }
}

/// Allows dictionary literals like `["name": "Ada", "count": 3]`.
extension JSONValue: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, JSONValue)...) {
    self = .object(Dictionary(elements, uniquingKeysWith: { _, new in new }))
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
