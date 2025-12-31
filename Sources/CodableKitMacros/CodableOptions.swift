//
//  CodableOptions.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/10/2.
//

import CodableKitCore
import SwiftSyntax

extension CodableOptions {
  init(from expr: MemberAccessExprSyntax) {
    let variableName = expr.declName.baseName.text
    switch variableName {
    case "skipSuperCoding":
      self = .skipSuperCoding
    case "skipProtocolConformance":
      self = .skipProtocolConformance
    default:
      self = .default
    }
  }
}

extension CodableOptions {
  /// Parse the options from 1a `LabelExprSyntax`. It support parse a single element like `.default`,
  /// or multiple elements like `[.ignored, .explicitNil]`
  static func parse(from labeledExpr: LabeledExprSyntax) -> Self {
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
  func parseCodableOptions() -> CodableOptions {
    CodableOptions.parse(from: self)
  }
}
