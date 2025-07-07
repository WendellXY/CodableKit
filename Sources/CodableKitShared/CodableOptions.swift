//
//  CodableOptions.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/1/13.
//

import SwiftSyntax

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

extension CodableOptions {
  package init(from expr: MemberAccessExprSyntax) {
    let variableName = expr.declName.baseName.text
    switch variableName {
    case "skipSuperCoding":
      self = .skipSuperCoding
    default:
      self = .default
    }
  }
}

extension CodableOptions {
  /// Parse the options from 1a `LabelExprSyntax`. It support parse a single element like `.default`,
  /// or multiple elements like `[.ignored, .explicitNil]`
  package static func parse(from labeledExpr: LabeledExprSyntax) -> Self {
    if let memberAccessExpr = labeledExpr.expression.as(MemberAccessExprSyntax.self) {
      Self.init(from: memberAccessExpr)
    } else if let arrayExpr = labeledExpr.expression.as(ArrayExprSyntax.self) {
      arrayExpr.elements
        .compactMap { $0.expression.as(MemberAccessExprSyntax.self) }
        .map { Self.init(from: $0) }
        .reduce(.default) { $0.union($1) }
    } else {
      .default
    }
  }
}

extension LabeledExprSyntax {
  /// Parse the options from a `LabelExprSyntax`. It support parse a single element like .default,
  /// or multiple elements like [.ignored, .explicitNil].
  ///
  /// This is a convenience method to use for chaining.
  package func parseCodableOptions() -> CodableOptions {
    CodableOptions.parse(from: self)
  }
}
