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
  private(set) var attributes: [AttributeSyntax]
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
  private init(
    attributes: [AttributeSyntax],
    declModifiers: [DeclModifierSyntax],
    binding: PatternBindingSyntax,
    defaultType type: TypeSyntax
  ) {
    self.attributes = attributes.sorted {
      $0.macroName < $1.macroName
    }
    self.declModifiers = declModifiers
    self.name = binding.pattern.trimmed
    self.type = binding.typeAnnotation?.type.trimmed ?? type.trimmed
    self.defaultValue = binding.initializer?.value
  }

  /// Initializes a `CodableMacro.Property` instance.
  ///
  /// - Parameters:
  ///   - attributes: The attributes associated with the macro.
  ///   - declModifiers: The declaration modifiers associated of the property.
  ///   - caseElement: The element of an enum case
  private init(
    attributes: [AttributeSyntax],
    declModifiers: [DeclModifierSyntax],
    caseElement: EnumCaseElementSyntax
  ) {
    self.attributes = attributes.sorted {
      $0.macroName < $1.macroName
    }
    self.declModifiers = declModifiers
    self.name = PatternSyntax(IdentifierPatternSyntax(identifier: caseElement.name.trimmed))
    self.type = "Never"
    self.defaultValue = nil
  }
}

extension CodableProperty {
  func generateProperty(for type: CodableType = .codable) -> CodableProperty {
    guard type != .codable else { return self }

    let desc: String =
      switch type {
      case .decodable: "DecodableKey"
      case .encodable: "EncodableKey"
      default: "CodableKey"
      }

    let attributes = self.attributes.filter {
      $0.macroName == desc
    }

    var copy = self
    copy.attributes = attributes
    return copy
  }

  func containsDifferentKeyPaths(for type: CodableType) -> Bool {
    switch type {
    case .codable:
      var decodingPath: [String] = []
      var encodingPath: [String] = []

      attributesLoop: for attribute in attributes {
        let path =
          attribute.arguments?.as(LabeledExprListSyntax.self)?.customCodableKeyPath ?? [name.trimmedDescription]
        switch attribute.macroName {
        case "DecodableKey":
          decodingPath = path
        case "EncodableKey":
          encodingPath = path
        default:
          decodingPath = path
          encodingPath = path
          break attributesLoop
        }
      }

      return decodingPath != encodingPath
    default: return false
    }
  }

  private var allCodableKeyLabeledExprList: [LabeledExprListSyntax] {
    attributes
      .filter(\.isCodableKeyMacro)
      .compactMap { $0.arguments?.as(LabeledExprListSyntax.self) }
  }

  var attachedKeyMacros: [String] {
    attributes
      .filter(\.isCodableKeyMacro)
      .map(\.macroName)
  }
}

extension CodableProperty {
  /// Check if the property is optional.
  var isOptional: Bool {
    type.as(OptionalTypeSyntax.self) != nil || type.as(IdentifierTypeSyntax.self)?.name.text == "Optional"
  }

  /// The access modifier of the property, if not found, it will default to `internal`
  var accessModifier: DeclModifierSyntax {
    declModifiers.first(where: \.name.isAccessModifierKeyword) ?? DeclModifierSyntax(name: .keyword(.internal))
  }

  /// The key path for the property as specified in `@CodableKey`, split by `.`, e.g. ["data", "uid"]
  var customCodableKeyPath: [String]? { allCodableKeyLabeledExprList.compactMap(\.customCodableKeyPath).first }

  /// The `CodableKey` attribute of the property, if this value is nil, the property name will be used as the key
  var customCodableKey: PatternSyntax? { allCodableKeyLabeledExprList.compactMap(\.customCodableKey).first }

  /// Options for customizing the behavior of a `CodableKey`.
  var options: CodableKeyMacro.Options {
    allCodableKeyLabeledExprList.compactMap { $0.getExpr(label: "options")?.parseOptions() }.first ?? .default
  }

  /// Indicates if the property should be considered as normal property, which mean it should be
  ///  encoded and decoded without changing any process.
  var isNormal: Bool {
    !options.contains(.ignored)
      && !options.contains(.transcodeRawString)
      && !(options.contains(.lossy) && (isArrayType || isSetType || isDictionaryType))
      && transformerExpr == nil
  }

  /// Indicates if the property should be ignored when encoding and decoding
  var ignored: Bool { options.contains(.ignored) }
}

extension CodableProperty {
  /// The transformer expression provided via `@CodableKey(transformer: ...)`
  var transformerExpr: ExprSyntax? {
    allCodableKeyLabeledExprList.compactMap { $0.getExpr(label: "transformer")?.expression }.first
  }
}

extension CodableProperty {
  /// Normalized property name, if the property has a custom CodableKey, it will be the custom key,
  /// otherwise it will be the property name. For coding key pattern binding, the normalized name is
  /// string joined by `.`.
  ///
  /// This normalized name could be considered as the unique identifier of the property.
  var normalizedName: String {
    customCodableKeyPath?.joined(separator: ".") ?? name.trimmedDescription
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

// MARK: - Lossy helpers
extension CodableProperty {
  /// The underlying non-optional type if wrapped in Optional
  private var nonOptionalType: TypeSyntax {
    if let opt = type.as(OptionalTypeSyntax.self) {
      return TypeSyntax(opt.wrappedType.trimmed)
    }
    if let ident = type.as(IdentifierTypeSyntax.self), ident.name.text == "Optional",
      let arg = ident.genericArgumentClause?.arguments.first?.argument
    {
      return "\(arg.trimmed)"
    }
    return type.trimmed
  }

  /// Whether the property type is an Array
  var isArrayType: Bool {
    let baseType = nonOptionalType
    if baseType.as(ArrayTypeSyntax.self) != nil { return true }
    if let ident = baseType.as(IdentifierTypeSyntax.self) {
      return ident.name.text == "Array" && (ident.genericArgumentClause?.arguments.count == 1)
    }
    return false
  }

  /// Whether the property type is a Set
  var isSetType: Bool {
    let baseType = nonOptionalType
    if let ident = baseType.as(IdentifierTypeSyntax.self) {
      return ident.name.text == "Set" && (ident.genericArgumentClause?.arguments.count == 1)
    }
    return false
  }

  /// Whether the property type is a Dictionary
  var isDictionaryType: Bool {
    let baseType = nonOptionalType
    if baseType.as(DictionaryTypeSyntax.self) != nil { return true }
    if let ident = baseType.as(IdentifierTypeSyntax.self) {
      return ident.name.text == "Dictionary" && (ident.genericArgumentClause?.arguments.count == 2)
    }
    return false
  }

  /// The element type if the property is an Array<T> or Set<T>
  var collectionElementType: TypeSyntax? {
    let baseType = nonOptionalType
    if let array = baseType.as(ArrayTypeSyntax.self) {
      return TypeSyntax(array.element.trimmed)
    }
    if let ident = baseType.as(IdentifierTypeSyntax.self),
      ident.name.text == "Array" || ident.name.text == "Set",
      let arg = ident.genericArgumentClause?.arguments.first?.argument
    {
      return TypeSyntax(arg.trimmed)
    }
    return nil
  }

  /// The key and value types if the property is a Dictionary<Key, Value>
  var dictionaryKeyAndValueTypes: (key: TypeSyntax, value: TypeSyntax)? {
    let baseType = nonOptionalType
    if let dict = baseType.as(DictionaryTypeSyntax.self) {
      return (TypeSyntax(dict.key.trimmed), TypeSyntax(dict.value.trimmed))
    }
    if let ident = baseType.as(IdentifierTypeSyntax.self),
      ident.name.text == "Dictionary",
      let args = ident.genericArgumentClause?.arguments,
      args.count == 2
    {
      let key = args[args.startIndex].argument
      let value = args[args.index(after: args.startIndex)].argument
      return ("\(key.trimmed)", "\(value.trimmed)")
    }
    return nil
  }

  /// Temporary wrapper variable name for lossy decoding
  var lossyWrapperName: PatternSyntax {
    PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("\(name)LossyWrapper")))
  }
}

extension CodableProperty {
  static func extract(from declaration: some DeclGroupSyntax) throws -> [Self] {
    let declarations = declaration.memberBlock.members.map(\.decl)

    let vars =
      try declarations
      .compactMap { $0.as(VariableDeclSyntax.self) }
      .filter { $0.bindings.first?.accessorBlock == nil }  // Ignore computed properties
      .flatMap(extract)

    let cases =
      try declarations
      .compactMap { $0.as(EnumCaseDeclSyntax.self) }
      .flatMap(extract)

    return vars + cases
  }

  /// Infer a simple literal type from an initializer expression when no type annotation is present.
  /// Currently supports String, Int, Double, and Bool literals.
  private static func inferType(from initializer: ExprSyntax?) -> TypeSyntax? {
    guard let expr = initializer else { return nil }
    // Unwrap simple parenthesized expression: represented as a single-element tuple expression
    if let tuple = expr.as(TupleExprSyntax.self), let only = tuple.elements.first, tuple.elements.count == 1 {
      return inferType(from: ExprSyntax(only.expression))
    }
    // Array literals with homogeneous simple literal elements
    if let array = expr.as(ArrayExprSyntax.self) {
      var sawString = false
      var sawBool = false
      var sawInt = false
      var sawDouble = false

      // Empty array cannot be inferred without context
      if array.elements.isEmpty { return nil }

      for element in array.elements {
        guard let elementType = inferType(from: ExprSyntax(element.expression)) else { return nil }
        switch "\(elementType)" {
        case "String": sawString = true
        case "Bool": sawBool = true
        case "Int": sawInt = true
        case "Double": sawDouble = true
        default: return nil
        }
      }

      // Ensure homogeneity across non-numeric categories
      let nonNumericKinds = (sawString ? 1 : 0) + (sawBool ? 1 : 0)
      if nonNumericKinds > 1 { return nil }
      if nonNumericKinds == 1 && (sawInt || sawDouble) { return nil }

      if sawString { return "[String]" }
      if sawBool { return "[Bool]" }
      if sawDouble { return "[Double]" }
      if sawInt { return "[Int]" }

      return nil
    }
    if expr.as(StringLiteralExprSyntax.self) != nil { return "String" }
    if expr.as(BooleanLiteralExprSyntax.self) != nil { return "Bool" }
    if expr.as(IntegerLiteralExprSyntax.self) != nil { return "Int" }
    if expr.as(FloatLiteralExprSyntax.self) != nil { return "Double" }
    // Handle negative numeric literals like -1 or -3.14
    if let prefix = expr.as(PrefixOperatorExprSyntax.self),
      prefix.operator.tokenKind == .prefixOperator("-")
    {
      let baseExpr = ExprSyntax(prefix.expression)
      if baseExpr.as(IntegerLiteralExprSyntax.self) != nil { return "Int" }
      if baseExpr.as(FloatLiteralExprSyntax.self) != nil { return "Double" }
    }
    return nil
  }

  static func extract(from variable: VariableDeclSyntax) throws -> [Self] {
    let attributes = variable.attributes.compactMap { $0.as(AttributeSyntax.self) }

    let modifiers = variable.modifiers.map { $0 }

    // Ignore static properties
    guard !modifiers.contains(where: \.name.isTypePropertyKeyword) else { return [] }

    let globalDefaultType = variable.bindings.last?.typeAnnotation?.type

    var properties: [Self] = []
    for binding in variable.bindings {
      // Prefer explicit type annotation on the binding, then a shared trailing annotation (e.g. `let a, b: String`),
      // then infer from a simple literal initializer.
      let fallbackType =
        binding.typeAnnotation?.type
        ?? globalDefaultType
        ?? inferType(from: binding.initializer?.value)

      if let fallbackType {
        let property = Self(
          attributes: attributes, declModifiers: modifiers, binding: binding, defaultType: fallbackType
        )
        try property.validated()
        properties.append(property)
        continue
      }

      // If we cannot determine a type and the property is ignored, skip it silently.
      let tmpProperty = Self(attributes: attributes, declModifiers: [], binding: binding, defaultType: "Any")
      if tmpProperty.ignored {
        continue
      }

      // Otherwise, emit the original error.
      throw SimpleDiagnosticMessage(
        message: "Properties must have a type annotation",
        severity: .error
      )
    }

    return properties
  }

  static func extract(from caseDecl: EnumCaseDeclSyntax) throws -> [Self] {
    let attributes = caseDecl.attributes.compactMap { $0.as(AttributeSyntax.self) }

    let modifiers = caseDecl.modifiers.map { $0 }

    return caseDecl.elements.map { element in
      Self(attributes: attributes, declModifiers: modifiers, caseElement: element)
    }
  }

  private func validated() throws {
    // Make sure the option (.generateCustomKey) is not repeated in different coding key macro
    let allOptions = allCodableKeyLabeledExprList.compactMap { $0.getExpr(label: nil)?.parseOptions() }
    if allOptions.count(where: { $0.contains(.generateCustomKey) }) > 1 {
      throw SimpleDiagnosticMessage(
        message: "`@CodableKey(options: .generateCustomKey)` is not supported for multiple pattern bindings",
        severity: .error
      )
    }
  }
}

// MARK: - Helpers

extension LabeledExprListSyntax {
  /// The key path for the property as specified in `@CodableKey`, split by `.`, e.g. ["data", "uid"]
  fileprivate var customCodableKeyPath: [String]? {
    guard
      let expr = getExpr(label: nil)?.expression.trimmed,
      expr.as(NilLiteralExprSyntax.self) == nil
    else {
      return nil
    }

    // the expr is something like `"customKey"`, we need to remove the quotes
    return "\(expr)".trimmingCharacters(in: .init(charactersIn: "\"")).components(separatedBy: ".")
  }

  /// The `CodableKey` attribute of the property, if this value is nil, the property name will be used as the key
  fileprivate var customCodableKey: PatternSyntax? {
    customCodableKeyPath?.last.map { identifier in
      PatternSyntax(IdentifierPatternSyntax(identifier: .identifier(identifier)))
    }
  }
}
