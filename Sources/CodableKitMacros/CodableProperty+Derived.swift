//
//  CodableProperty+Derived.swift
//  CodableKit
//
//  Created by Wendell Wang on 2026/6/11.
//

import SwiftSyntax

// MARK: - Derived property helpers (`@DerivedKey`)
extension CodableProperty {
  /// The `@DerivedKey` attribute attached to the property, if any.
  var derivedKeyAttribute: AttributeSyntax? {
    attributes.first { $0.macroName == "DerivedKey" }
  }

  /// Indicates if the property is derived: it has no coding key of its own and is computed at
  /// the end of `init(from:)` from an already-decoded sibling property.
  var isDerived: Bool { derivedKeyAttribute != nil }

  /// The name of the source property in `@DerivedKey(from:)`, when written as a plain string
  /// literal. `nil` when the argument is missing, empty, or not a simple string literal.
  var derivedFromPropertyName: String? {
    guard
      let expr = derivedKeyAttribute?.arguments?
        .as(LabeledExprListSyntax.self)?
        .getExpr(label: "from")?
        .expression,
      let stringLiteral = expr.as(StringLiteralExprSyntax.self),
      stringLiteral.segments.count == 1,
      let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
    else { return nil }

    let text = segment.content.text
    return text.isEmpty ? nil : text
  }

  /// The transformer expression provided via `@DerivedKey(transformer:)`.
  var derivedTransformerExpr: ExprSyntax? {
    derivedKeyAttribute?.arguments?
      .as(LabeledExprListSyntax.self)?
      .getExpr(label: "transformer")?
      .expression
  }
}
