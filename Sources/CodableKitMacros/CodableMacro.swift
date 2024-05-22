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
    try core.validateDeclaration(declaration)
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
    try core.validateDeclaration(declaration)
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
          InheritedTypeSyntax(type: "String" as TypeSyntax)
          InheritedTypeSyntax(type: "CodingKey" as TypeSyntax)
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
            "from decoder: Decoder"
          }
        ),
        effectSpecifiers: .init(
          throwsSpecifier: "throws"
        )
      )
    ) {
      "let container = try decoder.container(keyedBy: CodingKeys.self)"
      for property in properties where !property.ignored {
        let key = property.name
        let type = property.type
        if let defaultValue = property.defaultValue {
          "\(key) = try container.decodeIfPresent(\(type).self, forKey: .\(key)) ?? \(defaultValue)"
        } else if property.isOptional {
          "\(key) = try container.decodeIfPresent(\(type).self, forKey: .\(key)) ?? nil"
        } else {
          "\(key) = try container.decode(\(type).self, forKey: .\(key))"
        }
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
      name: "encode",
      signature: .init(
        parameterClause: .init(
          parametersBuilder: {
            "to encoder: Encoder"
          }
        ),
        effectSpecifiers: .init(
          throwsSpecifier: "throws"
        )
      )
    ) {
      "var container = encoder.container(keyedBy: CodingKeys.self)"
      for property in properties where !property.ignored {
        if property.isOptional && !property.options.contains(.explicitNil) {
          "try container.encodeIfPresent(\(property.name), forKey: .\(property.name))"
        } else {
          "try container.encode(\(property.name), forKey: .\(property.name))"
        }
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
