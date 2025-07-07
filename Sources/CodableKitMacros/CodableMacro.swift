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

public struct CodableMacro {
  internal static let core = CodeGenCore.shared
}

// MARK: - ExtensionMacro

extension CodableMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
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
                hasSuper: false
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
    try core.prepareCodeGeneration(of: node, for: declaration, in: context, conformingTo: protocols)

    let properties = try core.properties(for: declaration, in: context)
    let accessModifier = try core.accessModifier(for: declaration, in: context)
    let structureType = try core.accessStructureType(for: declaration, in: context)
    let codableType = try core.accessCodableType(for: declaration, in: context)
    let codableOptions = try core.accessCodableOptions(for: declaration, in: context)

    // If there are no properties, return an empty array.
    guard !properties.isEmpty else { return [] }

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
              hasSuper: hasSuper
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
              hasSuper: hasSuper
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
    hasSuper: Bool
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
      CodeBlockItemSyntax(item: .decl(core.genDecodeContainerDecl()))
      for property in properties where property.isNormal {
        CodeBlockItemSyntax(
          item: .expr(
            core.genContainerDecodeExpr(
              variableName: property.name,
              patternName: property.name,
              isOptional: property.isOptional,
              useDefaultOnFailure: property.options.contains(.useDefaultOnFailure),
              defaultValueExpr: property.defaultValue,
              type: property.type
            )
          )
        )
      }

      for property in properties where property.options.contains(.transcodeRawString) && !property.ignored {
        let key = property.name
        let rawKey = property.rawStringName
        CodeBlockItemSyntax(
          item: .decl(
            core.genContainerDecodeVariableDecl(
              variableName: rawKey,
              patternName: key,
              isOptional: property.isOptional,
              useDefaultOnFailure: property.options.contains(.useDefaultOnFailure),
              defaultValueExpr: ExprSyntax(StringLiteralExprSyntax(content: "")),
              type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("String")))
            )
          )
        )

        let defaultValueExpr = property.defaultValue ?? (property.isOptional ? "nil": nil)

        CodeBlockItemSyntax(
          item: .expr(
            core.genRawDataHandleExpr(
              key: property.name,
              rawDataName: property.rawDataName,
              rawStringName: property.rawStringName,
              defaultValueExpr: defaultValueExpr,
              type: property.type,
              message: "Failed to convert raw string to data"
            )
          )
        )
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
    hasSuper: Bool
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

      CodeBlockItemSyntax(item: .decl(core.genEncodeContainerDecl()))
      for property in properties where property.isNormal {
        CodeBlockItemSyntax(
          item: .expr(
            core.genContainerEncodeExpr(
              key: property.name,
              patternName: property.name,
              isOptional: property.isOptional,
              explicitNil: property.options.contains(.explicitNil)
            )
          )
        )
      }

      // Decode from the rawString.
      for property in properties where property.options.contains(.transcodeRawString) && !property.ignored {
        CodeBlockItemSyntax(
          item: .decl(
            core.genJSONEncoderEncodeDecl(
              variableName: property.rawDataName,
              instance: property.name
            )
          )
        )

        CodeBlockItemSyntax(
          item: .expr(
            core.genEncodeRawDataHandleExpr(
              key: property.name,
              rawDataName: property.rawDataName,
              rawStringName: property.rawStringName,
              message: "Failed to transcode raw data to string",
              isOptional: property.isOptional,
              explicitNil: property.options.contains(.explicitNil)
            )
          )
        )
      }

      if hasSuper, !codableOptions.contains(.skipSuperCoding) {
        "try super.encode(to: encoder)"
      }

      "try didEncode(to: encoder)"
    }
  }
}
