//
//  JSONValue+Compatibility.swift
//  CodableKit
//
//  Created by Wendell Wang on 2026/3/26.
//

import Foundation

// MARK: - Forgiving Initializers

extension JSONValue {
  /// Creates a `JSONValue` by parsing a JSON string, returning `.null` on failure.
  ///
  /// This is a forgiving alternative to `init(jsonString:)` that never throws.
  ///
  /// ```swift
  /// let value = JSONValue(parseJSON: rawString)
  /// let name = value["name"]?.stringValue ?? ""
  /// ```
  public init(parseJSON string: String) {
    self = (try? JSONValue(jsonString: string)) ?? .null
  }
}

// MARK: - Numeric Accessors

extension JSONValue {
  /// Returns the numeric value as `Int64`, converting from `.int`, `.double`, `.bool`, or numeric `.string`.
  public var int64Value: Int64? {
    switch self {
    case .int(let value): return Int64(value)
    case .double(let value): return Int64(exactly: value)
    case .bool(let value): return value ? 1 : 0
    case .string(let value):
      if let i = Int64(value) { return i }
      if let d = Double(value) { return Int64(exactly: d) }
      return nil
    default: return nil
    }
  }

  /// Returns the numeric value as `Int8`, converting from `.int`, `.double`, `.bool`, or numeric `.string`.
  public var int8Value: Int8? {
    switch self {
    case .int(let value): return Int8(exactly: value)
    case .double(let value): return Int8(exactly: value)
    case .bool(let value): return value ? 1 : 0
    case .string(let value):
      if let i = Int(value), let i8 = Int8(exactly: i) { return i8 }
      if let d = Double(value) { return Int8(exactly: d) }
      return nil
    default: return nil
    }
  }

  /// Returns the numeric value as `Double`, converting from `.int`, `.double`, `.bool`, or numeric `.string`.
  public var numberValue: Double? {
    switch self {
    case .int(let value): return Double(value)
    case .double(let value): return value
    case .bool(let value): return value ? 1.0 : 0.0
    case .string(let value): return Double(value)
    default: return nil
    }
  }
}

// MARK: - Serialization (Non-Throwing)

extension JSONValue {
  /// Encodes the value as JSON `Data`, returning `nil` on failure.
  public var rawData: Data? {
    try? jsonData()
  }

  /// Encodes the value as a JSON string, returning `nil` on failure.
  public var rawString: String? {
    try? jsonString()
  }
}

// MARK: - Foundation Bridging

extension JSONValue {
  /// Converts the value to an untyped Foundation object tree.
  ///
  /// - `.null` → `NSNull()`
  /// - `.bool` → `Bool`
  /// - `.string` → `String`
  /// - `.int` → `Int`
  /// - `.double` → `Double`
  /// - `.array` → `[Any]`
  /// - `.object` → `[String: Any]`
  public var anyValue: Any {
    switch self {
    case .null: NSNull()
    case .bool(let v): v
    case .string(let v): v
    case .int(let v): v
    case .double(let v): v
    case .array(let v): v.map(\.anyValue)
    case .object(let v): v.mapValues(\.anyValue)
    }
  }

  /// Returns the underlying array as `[Any]` when the value is `.array`.
  public var arrayObject: [Any]? {
    guard case .array(let values) = self else { return nil }
    return values.map(\.anyValue)
  }

  /// Returns the underlying object as `[String: Any]` when the value is `.object`.
  public var dictionaryObject: [String: Any]? {
    guard case .object(let values) = self else { return nil }
    return values.mapValues(\.anyValue)
  }
}
