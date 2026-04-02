//
//  JSONValue+Coercion.swift
//  CodableKit
//
//  Created by Wendell Wang on 2026/4/2.
//

// MARK: - Coercing Type Accessors

extension JSONValue {

  // MARK: Bool

  private static let truthyStrings: Set<String> = ["true", "t", "yes", "y", "1"]
  private static let falsyStrings: Set<String> = ["false", "f", "no", "n", "0"]

  /// Returns a `Bool` by coercing from the underlying value.
  ///
  /// Coercion rules:
  /// - `.bool` → direct value
  /// - `.int` → `true` when non-zero
  /// - `.double` → `true` when non-zero
  /// - `.string` → `true` for `"true"`, `"t"`, `"yes"`, `"y"`, `"1"` (case-insensitive);
  ///   `false` for `"false"`, `"f"`, `"no"`, `"n"`, `"0"` (case-insensitive);
  ///   `nil` for all other strings
  /// - `.null`, `.array`, `.object` → `nil`
  public var coercedBoolValue: Bool? {
    switch self {
    case .bool(let value):
      return value
    case .int(let value):
      return value != 0
    case .double(let value):
      return value != 0
    case .string(let value):
      let lowered = value.lowercased()
      if Self.truthyStrings.contains(lowered) { return true }
      if Self.falsyStrings.contains(lowered) { return false }
      return nil
    case .null, .array, .object:
      return nil
    }
  }

  // MARK: Int

  /// Returns an `Int` by coercing from the underlying value.
  ///
  /// Coercion rules:
  /// - `.int` → direct value
  /// - `.double` → exact conversion via `Int(exactly:)` (returns `nil` for fractional values)
  /// - `.bool` → `1` for `true`, `0` for `false`
  /// - `.string` → parsed via `Int(_:)`, falling back to `Double` → `Int(exactly:)` for strings like `"3.0"`
  /// - `.null`, `.array`, `.object` → `nil`
  public var coercedIntValue: Int? {
    switch self {
    case .int(let value):
      return value
    case .double(let value):
      return Int(exactly: value)
    case .bool(let value):
      return value ? 1 : 0
    case .string(let value):
      if let intValue = Int(value) { return intValue }
      if let doubleValue = Double(value) { return Int(exactly: doubleValue) }
      return nil
    case .null, .array, .object:
      return nil
    }
  }

  // MARK: Double

  /// Returns a `Double` by coercing from the underlying value.
  ///
  /// Coercion rules:
  /// - `.double` → direct value
  /// - `.int` → widened to `Double`
  /// - `.bool` → `1.0` for `true`, `0.0` for `false`
  /// - `.string` → parsed via `Double(_:)`
  /// - `.null`, `.array`, `.object` → `nil`
  public var coercedDoubleValue: Double? {
    switch self {
    case .double(let value):
      return value
    case .int(let value):
      return Double(value)
    case .bool(let value):
      return value ? 1.0 : 0.0
    case .string(let value):
      return Double(value)
    case .null, .array, .object:
      return nil
    }
  }

  // MARK: String

  /// Returns a `String` by coercing from the underlying value.
  ///
  /// Coercion rules:
  /// - `.string` → direct value
  /// - `.bool` → `"true"` or `"false"`
  /// - `.int` → string representation
  /// - `.double` → string representation
  /// - `.null` → `"null"`
  /// - `.array`, `.object` → `nil`
  public var coercedStringValue: String? {
    switch self {
    case .string(let value):
      return value
    case .bool(let value):
      return value ? "true" : "false"
    case .int(let value):
      return String(value)
    case .double(let value):
      return String(value)
    case .null:
      return "null"
    case .array, .object:
      return nil
    }
  }
}
