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

public struct CodableMacro: ExtensionMacro {
  private static let messageID = MessageID(domain: "CodableKit", id: "CodableMacro")

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // Validate that the macro is being applied to a struct declaration
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      throw SimpleDiagnosticMessage(
        message: "Macro `CodableMacro` can only be applied to a struct",
        diagnosticID: messageID,
        severity: .error
      )
    }

    let accessModifiers: Set = ["public", "private", "internal"]

    let accessModifier =
      if let accessModifier = structDecl.modifiers.first(where: { accessModifiers.contains($0.name.text) }) {
        accessModifier
      } else {
        DeclModifierSyntax(name: "internal")
      }

    let properties = try extractProperties(from: structDecl)

    guard !properties.isEmpty else { return [] }

    let inheritanceClause = InheritanceClauseSyntax {
      InheritedTypeSyntax(type: "Codable" as TypeSyntax)
    }

    var extensionDecls: [ExtensionDeclSyntax] = []

    let codableExtensionDecl = ExtensionDeclSyntax(
      extendedType: type, inheritanceClause: inheritanceClause
    ) {
      genCodingKeyEnumDecl(from: properties)
      genInitDecoderDecl(from: properties, modifiers: [accessModifier])
      genEncodeFuncDecl(from: properties, modifiers: [accessModifier])
    }

    let customKeysExtensionDecl = ExtensionDeclSyntax(
      extendedType: type
    ) {
      let generatingProperties = properties.filter(\.shouldGenerateCustomCodingKeyVariable)
      for (index, property) in generatingProperties.enumerated() {
        genCustomKeyVariable(for: property, modifiers: [accessModifier], isFirst: index == 0)
      }
    }

    extensionDecls.append(codableExtensionDecl)

    if properties.map(\.shouldGenerateCustomCodingKeyVariable).contains(true) {
      extensionDecls.append(customKeysExtensionDecl)
    }

    return extensionDecls
  }
}

// MARK: - Supporting Method
extension CodableMacro {
  /// Extract all the properties from structure and add type info.
  fileprivate static func extractProperties(from declaration: some DeclGroupSyntax) throws -> [Property] {
    try declaration.memberBlock.members
      .map(\.decl)
      .compactMap { declaration in
        declaration.as(VariableDeclSyntax.self)
      }
      .filter { variable in
        variable.bindings.first?.accessorBlock == nil
      }
      .flatMap { variable -> [Property] in
        let attributes = variable.attributes.compactMap { $0.as(AttributeSyntax.self) }

        let modifiers = variable.modifiers.map { $0.name.text }

        // Ignore static properties
        guard !modifiers.contains("static") else { return [] }

        guard let defaultType = variable.bindings.last?.typeAnnotation?.type else {
          throw SimpleDiagnosticMessage(
            message: "Properties must have a type annotation",
            diagnosticID: messageID,
            severity: .error
          )
        }

        return variable.bindings.map { binding in
          Property(attributes: attributes, binding: binding, defaultType: defaultType)
        }
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
    modifiers: DeclModifierListSyntax,
    isFirst: Bool = false
  ) -> VariableDeclSyntax {
    let pattern = PatternBindingSyntax(
      pattern: property.customCodableKey!,
      typeAnnotation: TypeAnnotationSyntax(type: property.type),
      accessorBlock: AccessorBlockSyntax(
        leadingTrivia: .space,
        leftBrace:  .leftBraceToken(),
        accessors: .getter("\(property.name)"),
        rightBrace: .rightBraceToken()
      )
    )

    return VariableDeclSyntax(
      leadingTrivia: isFirst ? .none : .newline,
      modifiers: modifiers,
      bindingSpecifier: .keyword(.var),
      bindings: [pattern]
    )
  }
}
