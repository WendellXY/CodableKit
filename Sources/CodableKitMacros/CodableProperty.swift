//
//  CodableProperty.swift
//  CodableKit
//
//  Created by Wendell on 4/3/24.
//

import SwiftSyntax

extension CodableMacro {
  typealias Property = CodableProperty
}

extension CodableKeyMacro {
  typealias Property = CodableProperty
}

/// A simple property representation of the property in a group declaration syntax.
struct CodableProperty {
  /// The attributes of the property
  let attributes: [AttributeSyntax]
  /// The declaration modifiers of the property
  let declModifiers: [DeclModifierSyntax]
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
  ///   - declModifiers: The declaration modifiers associated of the property.
  ///   - binding: The pattern binding syntax.
  ///   - type: The default type syntax. Variable Decl might not have a type annotation like in
  ///  `let a, b: String`, so we need to pass the default type.
  init(
    attributes: [AttributeSyntax],
    declModifiers: [DeclModifierSyntax],
    binding: PatternBindingSyntax,
    defaultType type: TypeSyntax
  ) {
    self.attributes = attributes
    self.declModifiers = declModifiers
    self.name = binding.pattern
    self.type = binding.typeAnnotation?.type.trimmed ?? type.trimmed
    self.defaultValue = binding.initializer?.value
  }

  /// Initializes a `CodableMacro.Property` instance.
  ///
  /// - Parameters:
  ///   - attributes: The attributes associated with the macro.
  ///   - declModifiers: The declaration modifiers associated of the property.
  ///   - caseElement: The element of an enum case
  init(
    attributes: [AttributeSyntax],
    declModifiers: [DeclModifierSyntax],
    caseElement: EnumCaseElementSyntax
  ) {
    self.attributes = attributes
    self.declModifiers = declModifiers
    self.name = PatternSyntax(IdentifierPatternSyntax(identifier: caseElement.name))
    self.type = "Never"
    self.defaultValue = nil
  }
}

extension CodableProperty {
  /// Check if the property is optional.
  var isOptional: Bool {
    type.as(OptionalTypeSyntax.self) != nil || type.as(IdentifierTypeSyntax.self)?.name.text == "Optional"
  }

  private var codableKeyLabeledExprList: LabeledExprListSyntax? {
    attributes.first(where: {
      $0.attributeName.as(IdentifierTypeSyntax.self)?.description == "CodableKey"
    })?.arguments?.as(LabeledExprListSyntax.self)
  }

  /// The access modifier of the property, if not found, it will default to `internal`
  var accessModifier: DeclModifierSyntax {
    declModifiers.first(where: \.name.isAccessModifierKeyword) ?? DeclModifierSyntax(name: .keyword(.internal))
  }

  /// The key path for the property as specified in `@CodableKey`, split by `.`, e.g. ["data", "uid"]
  var customCodableKeyPath: [String]? {
    guard
      let expr = codableKeyLabeledExprList?.first(where: {
        $0.label == nil  // the first argument without label is the custom Codable Key
      })?.expression,
      expr.as(NilLiteralExprSyntax.self) == nil
    else {
      return nil
    }

    // the expr is something like `"customKey"`, we need to remove the quotes
    return "\(expr)".trimmingCharacters(in: .init(charactersIn: "\"")).components(separatedBy: ".")
  }

  /// The `CodableKey` attribute of the property, if this value is nil, the property name will be used as the key
  var customCodableKey: PatternSyntax? {
    if let identifier = customCodableKeyPath?.last {
      PatternSyntax(IdentifierPatternSyntax(identifier: .identifier(identifier)))
    } else {
      nil
    }
  }

  /// Options for customizing the behavior of a `CodableKey`.
  var options: CodableKeyMacro.Options {
    codableKeyLabeledExprList?.first(where: {
      $0.label?.text == "options"
    })?.parseOptions() ?? .default
  }

  /// Indicates if the property should be considered as normal property, which mean it should be
  ///  encoded and decoded without changing any process.
  var isNormal: Bool {
    !options.contains(.ignored) && !options.contains(.transcodeRawString)
  }

  /// Indicates if the property should be ignored when encoding and decoding
  var ignored: Bool {
    options.contains(.ignored)
  }
}

extension CodableProperty {
  var shouldGenerateCustomCodingKeyVariable: Bool {
    customCodableKey != nil && options.contains(.generateCustomKey)
  }

  func checkOptionsAvailability(for type: StructureType) throws(CustomError) {
    switch type {
    case .enumType:
      if !options.isEmpty && options != [.ignored] {
        throw CustomError.message("`enum` type does not support any options except `.ignored`")
      }
    case .structType, .classType:
      break
    }
  }
}

extension CodableProperty {
  var rawStringName: PatternSyntax {
    PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("\(name)RawString")))
  }
  var rawDataName: PatternSyntax {
    PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("\(name)RawData")))
  }
}

extension CodableProperty {
  static func extract(from declaration: some DeclGroupSyntax) throws -> [Self] {
    let declarations = declaration.memberBlock.members.map(\.decl)

    let vars = try declarations
      .compactMap { $0.as(VariableDeclSyntax.self) }
      .filter { $0.bindings.first?.accessorBlock == nil } // Ignore computed properties
      .flatMap(extract)

    let cases = try declarations
        .compactMap { $0.as(EnumCaseDeclSyntax.self) }
        .flatMap(extract)

    return vars + cases
  }

  static func extract(from variable: VariableDeclSyntax) throws -> [Self] {
    let attributes = variable.attributes.compactMap { $0.as(AttributeSyntax.self) }

    let modifiers = variable.modifiers.map { $0 }

    // Ignore static properties
    guard !modifiers.contains(where: \.name.isTypePropertyKeyword) else { return [] }

    guard let defaultType = variable.bindings.last?.typeAnnotation?.type else {
      // If no binding is found, return empty array.
      guard let lastBinding = variable.bindings.last else { return [] }
      // To check if a property is ignored, create a temporary property. If the property is ignored, return an empty
      // array. Otherwise, throw an error.
      let tmpProperty = Self(attributes: attributes, declModifiers: [], binding: lastBinding, defaultType: "Any")

      if tmpProperty.ignored {
        return []
      } else {
        throw SimpleDiagnosticMessage(
          message: "Properties must have a type annotation",
          severity: .error
        )
      }
    }

    return variable.bindings.map { binding in
      Self(attributes: attributes, declModifiers: modifiers, binding: binding, defaultType: defaultType)
    }
  }

  static func extract(from caseDecl: EnumCaseDeclSyntax) throws -> [Self] {
    let attributes = caseDecl.attributes.compactMap { $0.as(AttributeSyntax.self) }

    let modifiers = caseDecl.modifiers.map { $0 }

    return caseDecl.elements.map { element in
      Self(attributes: attributes, declModifiers: modifiers, caseElement: element)
    }
  }
}
