//
//  CodableMacro.swift
//  CodableKit
//
//  Created by Wendell on 3/30/24.
//

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
    try core.prepareCodeGeneration(for: declaration, in: context)

    let properties = try core.properties(for: declaration, in: context)
    let accessModifier = try core.accessModifier(for: declaration, in: context)
    let structureType = try core.accessStructureType(for: declaration, in: context)

    // If there are no properties, return an empty array.
    guard !properties.isEmpty else { return [] }

    let inheritanceClause: InheritanceClauseSyntax? =
      if case .classType(let hasSuperclass) = structureType, hasSuperclass {
        nil
      } else {
        InheritanceClauseSyntax {
          InheritedTypeSyntax(type: "Codable" as TypeSyntax)
        }
      }

    return switch structureType {
    case .classType:
      [
        ExtensionDeclSyntax(
          extendedType: type, inheritanceClause: inheritanceClause
        ) {
          genCodingKeyEnumDecl(from: properties)
        }
      ]
    case .structType:
      [
        ExtensionDeclSyntax(
          extendedType: type, inheritanceClause: inheritanceClause
        ) {
          genCodingKeyEnumDecl(from: properties)
          DeclSyntax(genInitDecoderDecl(from: properties, modifiers: [accessModifier], hasSuper: false))
        }
      ]
    case .enumType:
      [
        ExtensionDeclSyntax(
          extendedType: type, inheritanceClause: inheritanceClause
        ) {
          genCodingKeyEnumDecl(from: properties)
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
    try core.prepareCodeGeneration(for: declaration, in: context)

    let properties = try core.properties(for: declaration, in: context)
    let accessModifier = try core.accessModifier(for: declaration, in: context)
    let structureType = try core.accessStructureType(for: declaration, in: context)

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
        encodeModifiers.append(.init(name: .keyword(.override)))
        hasSuper = true
      }
    case .structType, .enumType:
      break
    }

    return switch structureType {
    case .classType:
      [
        DeclSyntax(genInitDecoderDecl(from: properties, modifiers: decodeModifiers, hasSuper: hasSuper)),
        DeclSyntax(genEncodeFuncDecl(from: properties, modifiers: encodeModifiers, hasSuper: hasSuper)),
      ]
    case .structType:  // Move the init logic to an extension to enable an automatic init method for the struct.
      [
        DeclSyntax(genEncodeFuncDecl(from: properties, modifiers: encodeModifiers, hasSuper: hasSuper))
      ]
    case .enumType:
      [
        // Not implemented
      ]
    }
  }
}

// MARK: - Boilerplate Code Generation

// MARK: Codable
extension CodableMacro {
  /// Generate the `CodingKeys` enum declaration.
  ///
  /// If a property has a `CodableKey` attribute, use the key passed in the attribute, otherwise use the property name.
  fileprivate static func genCodingKeyEnumDecl(from properties: [Property]) -> EnumDeclSyntax {
    EnumDeclSyntax(
      name: "CodingKeys",
      inheritanceClause: .init(
        inheritedTypesBuilder: {
          InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("String")))
          InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("CodingKey")))
        }
      )
    ) {
      for property in properties where !property.ignored {
        if let customCodableKey = property.customCodableKey {
          "case \(property.name) = \"\(customCodableKey)\""
        } else {
          "case \(property.name)"
        }
      }
    }
  }

  /// Generate the `init(from decoder: Decoder)` method of the `Codable` protocol.
  fileprivate static func genInitDecoderDecl(
    from properties: [Property],
    modifiers: [DeclModifierSyntax],
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

        CodeBlockItemSyntax(
          item: .expr(
            core.genRawDataHandleExpr(
              key: property.name,
              rawDataName: property.rawDataName,
              rawStringName: property.rawStringName,
              defaultValueExpr: property.defaultValue,
              type: property.type,
              message: "Failed to convert raw string to data"
            )
          )
        )
      }

      if hasSuper {
        "try super.init(from: decoder)"
      }
    }
  }

  /// Generate the `func encode(to encoder: Encoder)` method of the `Codable` protocol.
  fileprivate static func genEncodeFuncDecl(
    from properties: [Property],
    modifiers: [DeclModifierSyntax],
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

      if hasSuper {
        "try super.encode(to: encoder)"
      }
    }
  }
}
