//
//  CodeGenCore.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/22
//  Copyright © 2024 WendellXY. All rights reserved.
//

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Currently supported structure type of the declaration
internal enum StructureType: Sendable {
  case structType
  case classType(hasSuperclass: Bool)
  case enumType
}

@preconcurrency  // Disable warning when turning on StrictConcurrency Swift feature
internal final class CodeGenCore: @unchecked Sendable {
  internal typealias Property = CodableMacro.Property
  internal typealias MacroContextKey = String

  /// Declarations that have been prepared for code generation
  private var preparedDeclarations: Set<MacroContextKey> = []
  private var properties: [MacroContextKey: [CodableMacro.Property]] = [:]
  private var accessModifiers: [MacroContextKey: DeclModifierSyntax] = [:]
  private var structureTypes: [MacroContextKey: StructureType] = [:]
  private var codableTypes: [MacroContextKey: CodableType] = [:]
  private var codableOptions: [MacroContextKey: CodableOptions] = [:]
  private var hooksPresence: [MacroContextKey: HooksPresence] = [:]

  func key(for declaration: some SyntaxProtocol, in context: some MacroExpansionContext) -> MacroContextKey {
    let location = context.location(of: declaration)
    let syntaxIdentifier = declaration.id.hashValue

    if let location {
      return "\(location.file):\(location.line):\(location.column):\(syntaxIdentifier)"
    } else {
      return "\(syntaxIdentifier)"
    }
  }
}

// MARK: - Type/Conformance Helpers

extension CodeGenCore {
  fileprivate static func lastIdentifierName(of type: some TypeSyntaxProtocol) -> String? {
    if let id = type.as(IdentifierTypeSyntax.self) {
      return id.name.trimmed.text
    }
    if let member = type.as(MemberTypeSyntax.self) {
      return member.name.trimmed.text
    }
    if let attributed = type.as(AttributedTypeSyntax.self) {
      return lastIdentifierName(of: attributed.baseType)
    }
    return nil
  }

  fileprivate static func directInheritedTypeNames(in declaration: some DeclGroupSyntax) -> Set<String> {
    Set(
      declaration.inheritanceClause?.inheritedTypes.compactMap { inherited in
        lastIdentifierName(of: inherited.type)
      } ?? []
    )
  }
}

// MARK: - Hooks Presence Model
internal enum HookArgKind: Sendable { case none, decoder, encoder }

internal struct Hook: Sendable {
  let name: String
  let kind: HookArgKind
  let isStatic: Bool
}

internal struct HooksPresence: Sendable {
  let willDecode: [Hook]
  let didDecode: [Hook]
  let willEncode: [Hook]
  let didEncode: [Hook]
  var hasAny: Bool { !willDecode.isEmpty || !didDecode.isEmpty || !willEncode.isEmpty || !didEncode.isEmpty }
}

extension CodeGenCore {
  func properties(
    for declaration: some SyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [Property] {
    properties[key(for: declaration, in: context)] ?? []
  }

  func accessModifier(
    for declaration: some SyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> DeclModifierSyntax {
    if let accessModifier = accessModifiers[key(for: declaration, in: context)] {
      return accessModifier
    }

    throw SimpleDiagnosticMessage(
      message: "Access modifier for declaration not found",
      severity: .error
    )
  }

  func accessStructureType(
    for declaration: some SyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> StructureType {
    if let structureType = structureTypes[key(for: declaration, in: context)] {
      return structureType
    }

    throw SimpleDiagnosticMessage(
      message: "Structure type for declaration not found",
      severity: .error
    )
  }

  func accessCodableType(
    for declaration: some SyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> CodableType {
    if let codableType = codableTypes[key(for: declaration, in: context)] {
      return codableType
    }

    throw SimpleDiagnosticMessage(
      message: "Codable type for declaration not found",
      severity: .error
    )
  }

  func accessCodableOptions(
    for declaration: some SyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> CodableOptions {
    if let codableOptions = codableOptions[key(for: declaration, in: context)] {
      return codableOptions
    }

    throw SimpleDiagnosticMessage(
      message: "Codable options for declaration not found",
      severity: .error
    )
  }

  func accessHooksPresence(
    for declaration: some SyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> HooksPresence {
    if let hooks = hooksPresence[key(for: declaration, in: context)] {
      return hooks
    }

    throw SimpleDiagnosticMessage(
      message: "Hooks presence for declaration not found",
      severity: .error
    )
  }
}

// MARK: - Code Generation Preparation
extension CodeGenCore {
  /// Validate that the macro is being applied to a struct declaration
  fileprivate func validateDeclaration(
    for declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws {
    let id = key(for: declaration, in: context)
    // Struct
    if declaration.as(StructDeclSyntax.self) != nil {
      structureTypes[id] = .structType
      return
    }

    // Class
    if let declaration = declaration.as(ClassDeclSyntax.self) {
      // Check if the class has a superclass. Actually, it is impossible to check if a class has a
      // superclass or not during macro expansion. So, we just check if the inheritance clause is empty,
      // this is a trade-off, otherwise, we cannot implement @Codable as expected.
      let hasSuperclass = declaration.inheritanceClause?.inheritedTypes.isEmpty == false
      structureTypes[id] = .classType(hasSuperclass: hasSuperclass)
      return
    }

    // Enum
    if declaration.as(EnumDeclSyntax.self) != nil {
      structureTypes[id] = .enumType
      return
    }

    throw SimpleDiagnosticMessage(
      message: "Macro `CodableMacro` can only be applied to the struct, class or enum declaration.",
      severity: .error
    )
  }

  /// Prepare the code generation by extracting properties and access modifier.
  func prepareCodeGeneration(
    of node: AttributeSyntax,
    for declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext,
    conformingTo protocols: [TypeSyntax] = [],
    emitAdvisories: Bool = true
  ) throws {
    let id = key(for: declaration, in: context)

    func error(_ message: String) -> SimpleDiagnosticMessage {
      SimpleDiagnosticMessage(message: message, severity: .error)
    }

    guard preparedDeclarations.contains(id) == false else {
      // Since we have two macro implementations, so this method could be called twice. If in the first call, the
      // properties are not found, it means there are some errors in the first call. So, the error should be thrown
      // in the first call already. We just return here.
      return
    }

    let codableType = CodableType.from(protocols)
    codableTypes[id] = codableType

    try validateDeclaration(for: declaration, in: context)

    defer {
      preparedDeclarations.insert(id)
    }

    let options: CodableOptions =
      node.arguments?
      .as(LabeledExprListSyntax.self)?
      .first(where: { $0.label?.text == "options" })?
      .parseCodableOptions() ?? .default
    codableOptions[id] = options

    // By default, warn when the developer manually declares the same conformance that the macro provides.
    // This is advisory only; the extension macro may still omit attaching redundant conformances.
    if emitAdvisories, !options.contains(.skipProtocolConformance) {
      let inherited = Self.directInheritedTypeNames(in: declaration)

      func warn(_ message: String) {
        context.diagnose(
          Diagnostic(
            node: node,
            message: SimpleDiagnosticMessage(message: message, severity: .warning)
          )
        )
      }

      if codableType.contains(.codable) {
        if inherited.contains("Codable") {
          warn("Conformance 'Codable' is redundant when using @Codable")
        }
        if inherited.contains("Encodable") {
          warn("Conformance 'Encodable' is redundant when using @Codable")
        }
        if inherited.contains("Decodable") {
          warn("Conformance 'Decodable' is redundant when using @Codable")
        }
      } else if codableType.contains(.decodable) {
        if inherited.contains("Decodable") {
          warn("Conformance 'Decodable' is redundant when using @Decodable")
        }
      } else if codableType.contains(.encodable) {
        if inherited.contains("Encodable") {
          warn("Conformance 'Encodable' is redundant when using @Encodable")
        }
      }
    }

    // Check if properties and access modifier are already prepared

    if accessModifiers[id] == nil {
      accessModifiers[id] =
        if let accessModifier = declaration.modifiers.first(where: \.name.isAccessModifierKeyword) {
          accessModifier
        } else {
          DeclModifierSyntax(name: .keyword(.internal))
        }
    }

    if properties[id]?.isEmpty ?? true {
      let extractedProperties = try Property.extract(from: declaration)

      if extractedProperties.isEmpty {
        throw error("No properties found")
      }

      // Check if there are key conflicts
      let notIgnoredProperties = extractedProperties.filter({ !$0.ignored })
      var propertiesKeySet = Set(notIgnoredProperties.map(\.normalizedName))
      if propertiesKeySet.count != notIgnoredProperties.count {
        for property in notIgnoredProperties {
          if propertiesKeySet.contains(property.normalizedName) {
            propertiesKeySet.remove(property.normalizedName)
          } else {
            throw error("Key conflict found: \(property.normalizedName)")
          }
        }
      }

      for property in extractedProperties {
        let attachedKeyMacros = property.attachedKeyMacros
        // Validate the Key macro types, the CodableKey macro cannot be used with the DecodableKey and EncodableKey macro.
        if attachedKeyMacros.contains("CodableKey")
          && (attachedKeyMacros.contains("DecodableKey") || attachedKeyMacros.contains("EncodableKey"))
        {
          throw error("CodableKey macro cannot be used with the DecodableKey and EncodableKey macro")
        }

        // Make sure the same Key macro are not attached to the same property multiple times
        if attachedKeyMacros.count != Set(attachedKeyMacros).count {
          throw error("The same Key macro are not supported for multiple pattern bindings")
        }

        let attachedMacroType = attachedKeyMacros.reduce(into: CodableType.none) { $0.insert(CodableType.from($1)) }
        // Ensure that the Key macro matches the Container macro.
        // For instance, if the property is @DecodableKey, the container must be @Decodable or @Codable.
        // Mathematically, the attachedMacroType should share elements with the codableType.
        if attachedMacroType.intersection(codableType).isEmpty && attachedMacroType != .none && codableType != .none {
          throw error("The attached Key macro \(attachedMacroType) does not match the Container macro \(codableType)")
        }
      }

      properties[id] = extractedProperties
    }
    // Detect lifecycle hook methods on the declaration (only once per declaration)
    if hooksPresence[id] == nil {
      hooksPresence[id] = Self.detectHooks(in: declaration)
    }

    // v2 explicit hooks: warn when conventional hook method names exist without @CodableHook.
    if emitAdvisories {
      let relevantNames: Set<String> = if codableType.contains(.codable) {
        ["willDecode", "didDecode", "willEncode", "didEncode"]
      } else if codableType.contains(.decodable) {
        ["willDecode", "didDecode"]
      } else if codableType.contains(.encodable) {
        ["willEncode", "didEncode"]
      } else {
        []
      }

      func hasCodableHookAttribute(_ funcDecl: FunctionDeclSyntax) -> Bool {
        for attr in funcDecl.attributes {
          if let a = AttributeSyntax(attr),
            a.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "CodableHook"
          {
            return true
          }
        }
        return false
      }

      func stageToken(for conventionalName: String) -> String? {
        switch conventionalName {
        case "willDecode": "willDecode"
        case "didDecode": "didDecode"
        case "willEncode": "willEncode"
        case "didEncode": "didEncode"
        default: nil
        }
      }

      func looksLikeOldHookSignature(_ funcDecl: FunctionDeclSyntax, for name: String) -> Bool {
        let params = funcDecl.signature.parameterClause.parameters
        if params.count == 0 { return true }
        guard params.count == 1, let first = params.first else { return false }
        switch name {
        case "willDecode", "didDecode":
          return first.type.description.contains("Decoder")
        case "willEncode", "didEncode":
          return first.type.description.contains("Encoder")
        default:
          return false
        }
      }

      for member in declaration.memberBlock.members {
        guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }
        let name = funcDecl.name.text
        guard relevantNames.contains(name) else { continue }
        guard !hasCodableHookAttribute(funcDecl) else { continue }
        guard looksLikeOldHookSignature(funcDecl, for: name) else { continue }
        guard let stage = stageToken(for: name) else { continue }

        context.diagnose(
          Diagnostic(
            node: node,
            message: SimpleDiagnosticMessage(
              message: "Hook method '\(name)' will not be invoked unless annotated with @CodableHook(.\(stage))",
              severity: .error
            )
          )
        )
      }
    }
  }

  func prepareCodeGeneration(
    for declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext,
    with node: AttributeSyntax
  ) throws -> [Property] {
    let id = key(for: declaration, in: context)

    // Check if the declaration is a variable declaration
    guard var declaration = VariableDeclSyntax(declaration) else {
      if let caseDecl = EnumCaseDeclSyntax(declaration) {
        do {
          try Property.extract(from: caseDecl).forEach { proxy in
            try proxy.checkOptionsAvailability(for: .enumType)
          }
          return []
        } catch {
          throw SimpleDiagnosticMessage(
            message: error.localizedDescription,
            severity: .error
          )
        }
      } else {
        throw SimpleDiagnosticMessage(
          message: "Only variable declarations are supported",
          severity: .error
        )
      }
    }

    // Check if the variable is a compute property
    guard declaration.bindings.first?.accessorBlock == nil else {
      throw SimpleDiagnosticMessage(
        message: "Only variable declarations with no accessor block are supported",
        severity: .error
      )
    }

    // Check if the variable is not static or class property
    guard !declaration.modifiers.contains(where: \.name.isTypePropertyKeyword) else {
      throw SimpleDiagnosticMessage(
        message: "Only non-static variable declarations are supported",
        severity: .error
      )
    }

    declaration.attributes.append(.init(node))

    if properties[id]?.isEmpty ?? true {
      let extractedProperties = try Property.extract(from: declaration)

      for property in extractedProperties {
        if property.options.contains(.useDefaultOnFailure), !property.isOptional, property.defaultValue == nil {
          let message = "Option '.useDefaultOnFailure' has no effect for non-optional property without a default value"
          let diag = Diagnostic(node: node, message: SimpleDiagnosticMessage(message: message))
          context.diagnose(diag)
        }

        // Warn when `.explicitNil` is used on a non-optional property
        if property.options.contains(.explicitNil), !property.isOptional {
          let message = "Option '.explicitNil' has no effect on non-optional property"
          let diag = Diagnostic(node: node, message: SimpleDiagnosticMessage(message: message))
          context.diagnose(diag)
        }

        // Warn on `.lossy` used on unsupported type
        if property.options.contains(.lossy)
          && !(property.isArrayType || property.isSetType || property.isDictionaryType)
        {
          let message = "Option '.lossy' supports Array<T>, Set<T>, or Dictionary<K, V> properties"
          let diag = Diagnostic(node: node, message: SimpleDiagnosticMessage(message: message))
          context.diagnose(diag)
        }
      }

      guard !extractedProperties.isEmpty else {
        // for single variable declaration, if no property is found, which means the error should be thrown in the
        // extractProperty method. If the error is not thrown, it means the property is ignored.
        return []
      }

      // Since the properties extracted from the declaration share the same CodableKey, we can check the first property
      // to see if it has a custom CodableKey. And if there are some CodableKey options which support multiple pattern
      // bindings in the future, the following condition guard should not forbid them.
      if extractedProperties.count > 1 && extractedProperties.first?.customCodableKey != nil {
        context.diagnose(
          Diagnostic(
            node: node,
            message: SimpleDiagnosticMessage(
              message: "Custom Codable key not supported for multiple pattern bindings",
              severity: .error
            )
          )
        )
      }

      properties[id] = extractedProperties
    }

    return properties[id] ?? []
  }
}

// MARK: Code Generation Helpers
extension CodeGenCore {
  /// Generate a member access expression with a list of members like `A.B.C`.
  fileprivate static func genChainingMembers(
    _ names: some Collection<String>,
    attachedTo expr: ExprSyntax? = nil
  ) -> ExprSyntax {
    if let first = names.first {
      switch names.count {
      case 1: ExprSyntax(fromProtocol: MemberAccessExprSyntax(name: .identifier(first)))
      case 2:
        ExprSyntax(
          fromProtocol: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier(first)),
            declName: DeclReferenceExprSyntax(baseName: .identifier(names.dropFirst().first!))
          )
        )
      default:
        genChainingMembers(
          names.dropFirst(),
          attachedTo: ExprSyntax(
            fromProtocol: MemberAccessExprSyntax(
              base: expr,
              declName: DeclReferenceExprSyntax(baseName: .identifier(first))
            )
          )
        )
      }
    } else {
      expr!
    }
  }

  static func genChainingMembers(_ names: String...) -> MemberAccessExprSyntax {
    genChainingMembers(names, attachedTo: nil).as(MemberAccessExprSyntax.self)!
  }
}

extension CodeGenCore {
  /// Generate a variable declaration.
  static func genVariableDecl(
    bindingSpecifier: TokenSyntax = .keyword(.let),
    name: String,
    type: String? = nil,
    initializer: (some ExprSyntaxProtocol)? = nil
  ) -> VariableDeclSyntax {
    let typeAnnotation = type.map {
      TypeAnnotationSyntax(type: TypeSyntax(IdentifierTypeSyntax(name: .identifier($0))))
    }
    let initializerClause = initializer.map { InitializerClauseSyntax(value: $0) }
    return VariableDeclSyntax(bindingSpecifier: bindingSpecifier) {
      PatternBindingSyntax(
        pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
        typeAnnotation: typeAnnotation,
        initializer: initializerClause
      )
    }
  }
}

// MARK: - Hook Detection
extension CodeGenCore {
  /// Detect lifecycle hook methods defined in the declaration.
  /// v2 behavior: hooks are explicit — only annotated hooks (@CodableHook) are invoked.
  fileprivate static func detectHooks(in declaration: some DeclGroupSyntax) -> HooksPresence {
    var willDecode: [Hook] = []
    var didDecode: [Hook] = []
    var willEncode: [Hook] = []
    var didEncode: [Hook] = []

    func typeContains(_ param: FunctionParameterSyntax, token: String) -> Bool {
      param.type.description.contains(token)
    }

    // First pass: annotated hooks
    for member in declaration.memberBlock.members {
      guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }
      let attributes = funcDecl.attributes
      guard attributes.isEmpty == false else { continue }
      for attr in attributes {
        guard let attr = AttributeSyntax(attr),
          attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "CodableHook"
        else { continue }
        guard let arg = attr.arguments?.as(LabeledExprListSyntax.self)?.first?.expression else { continue }
        let stage = arg.description
        switch true {
        case stage.contains("willDecode"):
          // Must be static/class & accept Decoder
          let isStatic = funcDecl.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" })
          if isStatic {
            let params = funcDecl.signature.parameterClause.parameters
            let kind: HookArgKind =
              if let first = params.first, typeContains(first, token: "Decoder") { .decoder } else { .none }
            willDecode.append(.init(name: funcDecl.name.text, kind: kind, isStatic: true))
          }
        case stage.contains("didDecode"):
          let params = funcDecl.signature.parameterClause.parameters
          let kind: HookArgKind =
            if let first = params.first, typeContains(first, token: "Decoder") { .decoder } else { .none }
          didDecode.append(.init(name: funcDecl.name.text, kind: kind, isStatic: false))
        case stage.contains("willEncode"):
          let params = funcDecl.signature.parameterClause.parameters
          let kind: HookArgKind =
            if let first = params.first, typeContains(first, token: "Encoder") { .encoder } else { .none }
          willEncode.append(.init(name: funcDecl.name.text, kind: kind, isStatic: false))
        case stage.contains("didEncode"):
          let params = funcDecl.signature.parameterClause.parameters
          let kind: HookArgKind =
            if let first = params.first, typeContains(first, token: "Encoder") { .encoder } else { .none }
          didEncode.append(.init(name: funcDecl.name.text, kind: kind, isStatic: false))
        default: break
        }
      }
    }

    return HooksPresence(willDecode: willDecode, didDecode: didDecode, willEncode: willEncode, didEncode: didEncode)
  }
}
