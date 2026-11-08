//
//  CodableOptions.swift
//  CodableKitCore
//
//  Shared (runtime + macro implementation) option definitions.
//

/// Options that customize the behavior of the `@Codable` / `@Decodable` / `@Encodable` macro expansion.
public struct CodableOptions: OptionSet, Sendable {
  public let rawValue: Int32

  public init(rawValue: Int32) {
    self.rawValue = rawValue
  }

  /// The default options, which perform standard Codable expansion with super encode/decode calls.
  public static let `default`: Self = []

  /// Skips generating super encode/decode calls in the expanded code.
  ///
  /// Use this option when the superclass doesn't conform to `Codable`.
  /// When enabled:
  /// - Replaces `super.init(from: decoder)` with `super.init()`
  /// - Removes `super.encode(to: encoder)` call entirely
  public static let skipSuperCoding = Self(rawValue: 1 << 0)

  /// Skips adding protocol conformances (`Codable`/`Decodable`/`Encodable`) to the generated extension.
  ///
  /// Use this option when you want to explicitly declare the conformance on the type yourself, e.g.:
  ///
  /// ```swift
  /// @Codable(options: .skipProtocolConformance)
  /// struct User: Codable { ... }
  /// ```
  public static let skipProtocolConformance = Self(rawValue: 1 << 1)
}
