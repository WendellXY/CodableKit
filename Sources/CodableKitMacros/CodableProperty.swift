//
//  CodableProperty.swift
//  CodableKit
//
//  Created by Wendell on 4/3/24.
//

import SwiftSyntax

extension CodableMacro {
  /// A simple property representation of the property in a group declaration syntax.
  struct Property {
    /// The attributes of the property
    let attributes: [AttributeSyntax]
    /// The name of the property
    let name: PatternSyntax
    /// The type of the property
    let type: TypeSyntax
    /// The default value of the property
    let defaultValue: ExprSyntax?

    /// Initializes a `CodableMacro.Property` instance.
    ///
    /// - Parameters:
    ///   - attributes: The attributes associated with the macro.
    ///   - binding: The pattern binding syntax.
    ///   - type: The default type syntax. Variable Decl might not have a type annotation like in
    ///  `let a, b: String`, so we need to pass the default type.
    init(
      attributes: [AttributeSyntax],
      binding: PatternBindingSyntax,
      defaultType type: TypeSyntax
    ) {
      self.attributes = attributes
      self.name = binding.pattern
      self.type = binding.typeAnnotation?.type.trimmed ?? type.trimmed
      self.defaultValue = binding.initializer?.value
    }
  }
}

extension CodableMacro.Property {
  /// Check if the property is optional.
  var isOptional: Bool {
    type.as(OptionalTypeSyntax.self) != nil || type.as(IdentifierTypeSyntax.self)?.name.text == "Optional"
  }

  private var codableKeyLabeledExprList: LabeledExprListSyntax? {
    attributes.first(where: {
      $0.attributeName.as(IdentifierTypeSyntax.self)?.description == "CodableKey"
    })?.arguments?.as(LabeledExprListSyntax.self)
  }

  /// The `CodableKey` attribute of the property, if this value is nil, the property name will be used as the key
  var customCodableKey: ExprSyntax? {
    guard
      let expr = codableKeyLabeledExprList?.first(where: {
        $0.label == nil  // the first argument without label is the custom Codable Key
      })?.expression,
      expr.as(NilLiteralExprSyntax.self) == nil
    else {
      return nil
    }

    return expr
  }

  /// Options for customizing the behavior of a `CodableKey`.
  var options: CodableKeyMacro.Options {
    codableKeyLabeledExprList?.first(where: {
      $0.label?.text == "options"
    })?.parseOptions() ?? .default
  }

  /// Indicates if the property should be ignored when encoding and decoding
  var ignored: Bool {
    options.contains(.ignored)
  }
}
