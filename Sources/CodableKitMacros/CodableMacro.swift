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
  private static let core = CodeGenCore()
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
    try core.prepareCodeGeneration(for: declaration)

    let properties = try core.properties(for: declaration)
    let accessModifier = try core.accessModifier(for: declaration)

    let inheritanceClause = InheritanceClauseSyntax {
      InheritedTypeSyntax(type: "Codable" as TypeSyntax)
    }

    return [
      ExtensionDeclSyntax(
        extendedType: type, inheritanceClause: inheritanceClause
      ) {
        genCodingKeyEnumDecl(from: properties)
        genInitDecoderDecl(from: properties, modifiers: [accessModifier])
        genEncodeFuncDecl(from: properties, modifiers: [accessModifier])
      }
    ]
  }
}

// MARK: - MemberMacro

extension CodableMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try core.prepareCodeGeneration(for: declaration)

    let properties = try core.properties(for: declaration)
    let accessModifier = try core.accessModifier(for: declaration)

    return properties.filter(\.shouldGenerateCustomCodingKeyVariable).compactMap { property in
      genCustomKeyVariable(for: property, modifiers: [accessModifier])
    }
    .map(DeclSyntax.init)
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
    modifiers: DeclModifierListSyntax
  ) -> InitializerDeclSyntax {
    InitializerDeclSyntax(
      leadingTrivia: .newline,
      modifiers: modifiers,
      signature: .init(
        parameterClause: .init(
          parametersBuilder: {
            "from decoder: any Decoder"
          }
        ),
        effectSpecifiers: .init(throwsSpecifier: .keyword(.throws))
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
    }
  }

  /// Generate the `func encode(to encoder: Encoder)` method of the `Codable` protocol.
  fileprivate static func genEncodeFuncDecl(
    from properties: [Property],
    modifiers: DeclModifierListSyntax
  ) -> FunctionDeclSyntax {
    FunctionDeclSyntax(
      leadingTrivia: .newline,
      modifiers: modifiers,
      name: .identifier("encode"),
      signature: .init(
        parameterClause: FunctionParameterClauseSyntax {
          "to encoder: any Encoder"
        },
        effectSpecifiers: .init(throwsSpecifier: .keyword(.throws))
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
    }
  }
}

// MARK: Others
extension CodableMacro {
  /// Generate the custom key variable for the property.
  fileprivate static func genCustomKeyVariable(
    for property: Property,
    modifiers: DeclModifierListSyntax
  ) -> VariableDeclSyntax? {
    guard let customCodableKey = property.customCodableKey else { return nil }

    let pattern = PatternBindingSyntax(
      pattern: customCodableKey,
      typeAnnotation: TypeAnnotationSyntax(type: property.type),
      accessorBlock: AccessorBlockSyntax(
        leadingTrivia: .space,
        leftBrace: .leftBraceToken(),
        accessors: .getter("\(property.name)"),
        rightBrace: .rightBraceToken()
      )
    )

    return VariableDeclSyntax(
      leadingTrivia: .newline,
      modifiers: modifiers,
      bindingSpecifier: .keyword(.var),
      bindings: [pattern]
    )
  }
}
