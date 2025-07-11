//
//  CodableMacro.swift
//  CodableKit
//
//  Created by Wendell on 3/30/24.
//

import CodableKitShared
import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CodableMacro: ExtensionMacro {
  // MARK: - ExtensionMacro
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let core = CodeGenCore()
    try core.prepareCodeGeneration(of: node, for: declaration, in: context, conformingTo: protocols)

    let properties = try core.properties(for: declaration, in: context)
    let accessModifier = try core.accessModifier(for: declaration, in: context)
    let structureType = try core.accessStructureType(for: declaration, in: context)
    let codableType = try core.accessCodableType(for: declaration, in: context)
    let codableOptions = try core.accessCodableOptions(for: declaration, in: context)

    // If there are no properties, return an empty array.
    guard !properties.isEmpty else { return [] }

    let namespaceTree = NamespaceNode.buildTree(from: properties)

    let inheritanceClause: InheritanceClauseSyntax? =
      if case .classType(let hasSuperclass) = structureType,
        hasSuperclass,
        !codableOptions.contains(.skipSuperCoding)
      {
        nil
      } else {
        InheritanceClauseSyntax {
          for `protocol` in protocols {
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
          for namespaceDecl in namespaceTree.allCodingKeysEnums {
            namespaceDecl
          }
        }
      ]
    case .structType:
      [
        ExtensionDeclSyntax(
          extendedType: type, inheritanceClause: inheritanceClause
        ) {
          for namespaceDecl in namespaceTree.allCodingKeysEnums {
            namespaceDecl
          }
          if codableType.contains(.decodable) {
            DeclSyntax(
              genInitDecoderDecl(
                from: properties,
                modifiers: [accessModifier],
                codableOptions: codableOptions,
                hasSuper: false,
                tree: namespaceTree
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
          for namespaceDecl in namespaceTree.allCodingKeysEnums {
            namespaceDecl
          }
        }
      ]
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
    try core.prepareCodeGeneration(of: node, for: declaration, in: context, conformingTo: protocols)

    let properties = try core.properties(for: declaration, in: context)
    let accessModifier = try core.accessModifier(for: declaration, in: context)
    let structureType = try core.accessStructureType(for: declaration, in: context)
    let codableType = try core.accessCodableType(for: declaration, in: context)
    let codableOptions = try core.accessCodableOptions(for: declaration, in: context)

    // If there are no properties, return an empty array.
    guard !properties.isEmpty else { return [] }

    let namespaceTree = NamespaceNode.buildTree(from: properties)

    var decodeModifiers = [accessModifier]
    var encodeModifiers = [accessModifier]

    // If the structure is a class and has a superclass, this should be set to true.
    // This flag is used to determine if the encode and decode methods
    var hasSuper = false

    switch structureType {
    case let .classType(hasSuperclass):
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
              tree: namespaceTree
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
              tree: namespaceTree
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
    tree: NamespaceNode
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
      for containerDecl in tree.decodeBlockItem {
        containerDecl
      }

      if hasSuper {
        if codableOptions.contains(.skipSuperCoding) {
          "super.init()"
        } else {
          "try super.init(from: decoder)"
        }
      }

      "try didDecode(from: decoder)"
    }
  }

  /// Generate the `func encode(to encoder: Encoder)` method of the `Codable` protocol.
  fileprivate static func genEncodeFuncDecl(
    from properties: [Property],
    modifiers: [DeclModifierSyntax],
    codableOptions: CodableOptions,
    hasSuper: Bool,
    tree: NamespaceNode
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
      "try willEncode(to: encoder)"

      for containerDecl in tree.encodeBlockItem {
        containerDecl
      }

      if hasSuper, !codableOptions.contains(.skipSuperCoding) {
        "try super.encode(to: encoder)"
      }

      "try didEncode(to: encoder)"
    }
  }
}
