//
//  CodableOptions.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/1/13.
//

/// Options that customize the behavior of the `@Codable` macro expansion.
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
}
