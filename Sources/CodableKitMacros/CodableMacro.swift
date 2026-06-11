//
//  CodableMacro.swift
//  CodableKit
//
//  Created by Wendell on 3/30/24.
//

import CodableKitCore
import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CodableMacro: ExtensionMacro {
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

  fileprivate static func declaredOrSatisfiedConformances(of declaration: some DeclGroupSyntax) -> Set<String> {
    let direct: Set<String> = Set(
      declaration.inheritanceClause?.inheritedTypes.compactMap { inherited in
        lastIdentifierName(of: inherited.type)
      } ?? []
    )

    // Swift stdlib: `Codable` is a typealias for `Decodable & Encodable`, so declaring one
    // implies conformance to the others (and repeating any of them is redundant).
    var satisfied = direct
    if direct.contains("Codable") {
      satisfied.formUnion(["Decodable", "Encodable"])
    }
    if direct.contains("Decodable") && direct.contains("Encodable") {
      satisfied.insert("Codable")
    }
    return satisfied
  }

  // MARK: - ExtensionMacro
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    do {
      let core = CodeGenCore()
      // Run preparation but do not emit advisory diagnostics here to avoid duplicate warnings.
      try core.prepareCodeGeneration(
        of: node, for: declaration, in: context, conformingTo: protocols, emitAdvisories: false)

      let properties = try core.properties(for: declaration, in: context)
      let accessModifier = try core.accessModifier(for: declaration, in: context)
      let structureType = try core.accessStructureType(for: declaration, in: context)
      let codableType = try core.accessCodableType(for: declaration, in: context)
      let codableOptions = try core.accessCodableOptions(for: declaration, in: context)
      let hooks = try core.accessHooksPresence(for: declaration, in: context)

      // If there are no properties, return an empty array.
      guard !properties.isEmpty else { return [] }

      // Derived properties have no coding key and never participate in container decode/encode.
      let codedProperties = properties.filter { !$0.isDerived }

      let needsSeparateKeys = codedProperties.contains { $0.containsDifferentKeyPaths(for: codableType) }

      let codingKeyDecls: [EnumDeclSyntax]
      let usingTree: NamespaceNode

      if needsSeparateKeys {
        let decodeTree = NamespaceNode.buildTree(.decodable, from: codedProperties)
        let encodeTree = NamespaceNode.buildTree(.encodable, from: codedProperties)
        usingTree = decodeTree
        codingKeyDecls = decodeTree.allCodingKeysEnums + encodeTree.allCodingKeysEnums
      } else {
        let sharedTree = NamespaceNode.buildTree(.codable, from: codedProperties)
        usingTree = sharedTree
        codingKeyDecls = sharedTree.allCodingKeysEnums
      }

      let alreadyConformsTo = declaredOrSatisfiedConformances(of: declaration)
      let protocolsToAttach = protocols.filter { proto in
        guard let name = lastIdentifierName(of: proto) else { return true }
        return !alreadyConformsTo.contains(name)
      }

      let inheritanceClause: InheritanceClauseSyntax? =
        if codableOptions.contains(.skipProtocolConformance) {
          nil
        } else if case .classType(let hasSuperclass) = structureType,
          hasSuperclass,
          !codableOptions.contains(.skipSuperCoding)
        {
          nil
        } else if protocolsToAttach.isEmpty {
          nil
        } else {
          InheritanceClauseSyntax {
            for `protocol` in protocolsToAttach {
              InheritedTypeSyntax(type: `protocol`)
            }
          }
        }

      return switch structureType {
      case .classType:
        [
          ExtensionDeclSyntax(
            extendedType: type, inheritanceClause: inheritanceClause
          ) {
            for namespaceDecl in codingKeyDecls { namespaceDecl }
          }
        ]
      case .structType:
        [
          ExtensionDeclSyntax(
            extendedType: type, inheritanceClause: inheritanceClause
          ) {
            for namespaceDecl in codingKeyDecls { namespaceDecl }
            if codableType.contains(.decodable) {
              DeclSyntax(
                genInitDecoderDecl(
                  from: properties,
                  modifiers: [accessModifier.witnessSafe],
                  codableOptions: codableOptions,
                  hasSuper: false,
                  tree: usingTree,
                  hooks: hooks
                )
              )
            }
          }
        ]
      case .enumType:
        [
          ExtensionDeclSyntax(
            extendedType: type, inheritanceClause: inheritanceClause
          ) {
            for namespaceDecl in codingKeyDecls { namespaceDecl }
          }
        ]
      }
    } catch is DiagnosticAlreadyEmitted {
      // The member macro path has already attached the diagnostic to the offending node.
      return []
    } catch is SimpleDiagnosticMessage {
      // Swallow known diagnostics here to avoid emitting duplicates across macro roles.
      // The member macro will surface the diagnostic once.
      return []
    } catch {
      throw error
    }
  }
}

// MARK: - MemberMacro

extension CodableMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let core = CodeGenCore()
    // Member macro path: allow advisory diagnostics to be emitted once here
    do {
      try core.prepareCodeGeneration(
        of: node, for: declaration, in: context, conformingTo: protocols, emitAdvisories: true
      )
    } catch is DiagnosticAlreadyEmitted {
      // The diagnostic is already attached to the offending node; abort generation silently.
      return []
    }

    let properties = try core.properties(for: declaration, in: context)
    let accessModifier = try core.accessModifier(for: declaration, in: context)
    let structureType = try core.accessStructureType(for: declaration, in: context)
    let codableType = try core.accessCodableType(for: declaration, in: context)
    let codableOptions = try core.accessCodableOptions(for: declaration, in: context)
    let hooks = try core.accessHooksPresence(for: declaration, in: context)

    // If there are no properties, return an empty array.
    guard !properties.isEmpty else { return [] }

    // Derived properties have no coding key and never participate in container decode/encode.
    let codedProperties = properties.filter { !$0.isDerived }

    let needsSeparateKeys = codedProperties.contains { $0.containsDifferentKeyPaths(for: codableType) }

    let decodeTree: NamespaceNode
    let encodeTree: NamespaceNode

    if needsSeparateKeys {
      decodeTree = NamespaceNode.buildTree(.decodable, from: codedProperties)
      encodeTree = NamespaceNode.buildTree(.encodable, from: codedProperties)
    } else {
      let sharedTree = NamespaceNode.buildTree(.codable, from: codedProperties)
      decodeTree = sharedTree
      encodeTree = sharedTree
    }

    var decodeModifiers = [accessModifier.witnessSafe]
    var encodeModifiers = [accessModifier.witnessSafe]

    // If the structure is a class and has a superclass, this should be set to true.
    // This flag is used to determine if the encode and decode methods
    var hasSuper = false

    switch structureType {
    case .classType(let hasSuperclass):
      decodeModifiers.append(.init(name: .keyword(.required)))
      if hasSuperclass {
        if !codableOptions.contains(.skipSuperCoding) {
          encodeModifiers.append(.init(name: .keyword(.override)))
        }
        hasSuper = true
      }
    case .structType, .enumType:
      break
    }

    var result: [DeclSyntax] = []

    switch structureType {
    case .classType:
      if codableType.contains(.decodable) {
        result.append(
          DeclSyntax(
            genInitDecoderDecl(
              from: properties,
              modifiers: decodeModifiers,
              codableOptions: codableOptions,
              hasSuper: hasSuper,
              tree: decodeTree,
              hooks: hooks
            )
          )
        )
      }
      fallthrough
    case .structType:
      if codableType.contains(.encodable) {
        result.append(
          DeclSyntax(
            genEncodeFuncDecl(
              from: properties,
              modifiers: encodeModifiers,
              codableOptions: codableOptions,
              hasSuper: hasSuper,
              tree: encodeTree,
              hooks: hooks
            )
          )
        )
      }
    case .enumType:
      // Not implemented
      break
    }
    return result
  }
}

// MARK: - Boilerplate Code Generation

// MARK: Codable
extension CodableMacro {
  /// Generate the `init(from decoder: Decoder)` method of the `Codable` protocol.
  fileprivate static func genInitDecoderDecl(
    from properties: [Property],
    modifiers: [DeclModifierSyntax],
    codableOptions: CodableOptions,
    hasSuper: Bool,
    tree: NamespaceNode,
    hooks: HooksPresence
  ) -> InitializerDeclSyntax {
    InitializerDeclSyntax(
      leadingTrivia: .newline,
      modifiers: DeclModifierListSyntax(modifiers),
      signature: .init(
        parameterClause: .init(
          parametersBuilder: {
            "from decoder: any Decoder"
          }
        ),
        effectSpecifiers: .init(throwsClause: .init(throwsSpecifier: .keyword(.throws)))
      )
    ) {
      // Call static willDecode hooks before any property decoding
      for hook in hooks.willDecode {
        switch hook.kind {
        case .decoder:
          "\(raw: hook.isThrowing ? "try " : "")Self.\(raw: hook.name)(from: decoder)"
        case .encoder, .none:
          "\(raw: hook.isThrowing ? "try " : "")Self.\(raw: hook.name)()"
        }
      }

      for containerDecl in tree.decodeBlockItem {
        containerDecl
      }

      // Derived properties: computed from already-decoded sibling values, in declaration order.
      // Emitted after all coded assignments and before the didDecode hooks so hooks observe them.
      for item in derivedPropertyAssignments(from: properties) {
        item
      }

      if hasSuper {
        if codableOptions.contains(.skipSuperCoding) {
          "super.init()"
        } else {
          "try super.init(from: decoder)"
        }
      }

      for hook in hooks.didDecode {
        switch hook.kind {
        case .decoder:
          "\(raw: hook.isThrowing ? "try " : "")\(raw: hook.name)(from: decoder)"
        case .encoder, .none:
          "\(raw: hook.isThrowing ? "try " : "")\(raw: hook.name)()"
        }
      }
    }
  }

  /// Generate the tail assignments for `@DerivedKey` properties in `init(from:)`.
  ///
  /// Each derived property is assigned by feeding the already-decoded source property through the
  /// transformer pipeline via the `__ckDecodeDerived` runtime helper, in declaration order.
  /// Failure policy mirrors `.useDefaultOnFailure` conventions: optional properties and
  /// properties with a default initializer value fall back to `nil`/the default on pipeline
  /// failure; non-optional properties without a default propagate the error.
  fileprivate static func derivedPropertyAssignments(from properties: [Property]) -> [CodeBlockItemSyntax] {
    properties
      .filter(\.isDerived)
      .compactMap { property in
        guard
          let transformerExpr = property.derivedTransformerExpr,
          let sourceName = property.derivedFromPropertyName
        else { return nil }

        // A `let` with an initializer can never be re-assigned in `init(from:)`. The peer macro
        // already diagnoses this; skip the tail assignment so the diagnostic is not followed by
        // confusing secondary compile errors in generated code.
        guard !(property.isConstant && property.defaultValue != nil) else { return nil }

        let callExpr: ExprSyntax =
          "__ckDecodeDerived(transformer: \(transformerExpr), from: \(raw: sourceName))"

        if property.isOptional || property.defaultValue != nil {
          return "\(property.name) = (try? \(callExpr)) ?? \(property.defaultValue ?? "nil")"
        } else {
          return "\(property.name) = try \(callExpr)"
        }
      }
  }

  /// Generate the `func encode(to encoder: Encoder)` method of the `Codable` protocol.
  fileprivate static func genEncodeFuncDecl(
    from properties: [Property],
    modifiers: [DeclModifierSyntax],
    codableOptions: CodableOptions,
    hasSuper: Bool,
    tree: NamespaceNode,
    hooks: HooksPresence
  ) -> FunctionDeclSyntax {
    FunctionDeclSyntax(
      leadingTrivia: .newline,
      modifiers: DeclModifierListSyntax(modifiers),
      name: .identifier("encode"),
      signature: .init(
        parameterClause: FunctionParameterClauseSyntax {
          "to encoder: any Encoder"
        },
        effectSpecifiers: .init(throwsClause: .init(throwsSpecifier: .keyword(.throws)))
      )
    ) {
      for hook in hooks.willEncode {
        switch hook.kind {
        case .encoder:
          "\(raw: hook.isThrowing ? "try " : "")\(raw: hook.name)(to: encoder)"
        case .decoder, .none:
          "\(raw: hook.isThrowing ? "try " : "")\(raw: hook.name)()"
        }
      }

      for containerDecl in tree.encodeBlockItem {
        containerDecl
      }

      if hasSuper, !codableOptions.contains(.skipSuperCoding) {
        "try super.encode(to: encoder)"
      }

      for hook in hooks.didEncode {
        switch hook.kind {
        case .encoder:
          "\(raw: hook.isThrowing ? "try " : "")\(raw: hook.name)(to: encoder)"
        case .decoder, .none:
          "\(raw: hook.isThrowing ? "try " : "")\(raw: hook.name)()"
        }
      }
    }
  }
}
