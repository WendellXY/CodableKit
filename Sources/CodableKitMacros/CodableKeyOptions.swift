//
//  CodableKeyOptions.swift
//  CodableKit
//
//  Created by Wendell on 4/3/24.
//

import SwiftSyntax

extension CodableKeyMacro {
  /// Options for customizing the behavior of a `CodableKey`.
  public struct Options: OptionSet {
    public let rawValue: Int32

    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    /// The key will be ignored when encoding and decoding.
    public static let ignored = Self(rawValue: 1 << 0)
    /// The key will be explicitly set to `nil` (`null`) when encoding and decoding.
    /// By default, the key will be omitted if the value is `nil`.
    public static let explicitNil = Self(rawValue: 1 << 1)
    /// The default options for a `CodableKey`.
    public static let `default`: Self = []
  }
}

// MARK: It will be nice to use a macro to generate this code below.
extension CodableKeyMacro.Options {
  fileprivate init(from expr: MemberAccessExprSyntax) {
    let variableName = expr.declName.baseName.text
    switch variableName {
    case "ignored":
      self = .ignored
    case "explicitNil":
      self = .explicitNil
    default:
      self = .default
    }
  }
}

extension CodableKeyMacro.Options {
  /// Parse the options from a `LabelExprSyntax`. It support parse a single element like .default,
  /// or multiple elements like [.ignored, .explicitNil]
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
  package func parseOptions() -> CodableKeyMacro.Options {
    CodableKeyMacro.Options.parse(from: self)
  }
}