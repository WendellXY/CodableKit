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

    let accessModifiers: Set<String> = ["public", "private", "internal"]

    let accessModifier =
      if let accessModifier = structDecl.modifiers.first(where: { accessModifiers.contains($0.name.text) }) {
        accessModifier
      } else {
        DeclModifierSyntax(name: "internal")
      }
    let properties = extractProperties(from: structDecl)

    guard !properties.isEmpty else { return [] }

    let inheritanceClause = InheritanceClauseSyntax {
      InheritedTypeSyntax(type: "Codable" as TypeSyntax)
    }

    let extensionDecl = ExtensionDeclSyntax(
      extendedType: type, inheritanceClause: inheritanceClause
    ) {
      genCodingKeyEnumDecl(from: properties)
      genInitDecoderDecl(from: properties, modifiers: [accessModifier])
      genEncodeFuncDecl(from: properties, modifiers: [accessModifier])
    }

    return [extensionDecl]
  }
}

// MARK: - Supporting Method

extension CodableMacro {

  /// A simple property representation of the property in a group declaration syntax.
  struct Property {
    /// The attributes of the property
    let attributes: [AttributeSyntax]
    /// The name of the property
    let name: PatternSyntax
    /// The type of the property
    let type: TypeSyntax
    /// The default value of the property
    let defaultValue: ExprSyntax?

    /// The `CodableKey` attribute of the property, if this value is nil, the property name will be used as the key
    var customCodableKey: ExprSyntax? {
      attributes.first(where: {
        $0.attributeName.as(IdentifierTypeSyntax.self)?.description == "CodableKey"
      })?.arguments?.as(LabeledExprListSyntax.self)?.first?.expression
    }

    init(
      attributes: [AttributeSyntax],
      binding: PatternBindingSyntax,
      defaultType type: TypeSyntax
    ) {
      self.attributes = attributes
      self.name = binding.pattern
      self.type = binding.typeAnnotation?.type.trimmed ?? type.trimmed
      self.defaultValue = binding.initializer?.value
    }
  }

  /// Extract all the properties from structure and add type info.
  fileprivate static func extractProperties(from declaration: some DeclGroupSyntax) -> [Property] {
    declaration.memberBlock.members
      .map(\.decl)
      .compactMap { declaration in
        declaration.as(VariableDeclSyntax.self)
      }
      .filter { variable in
        variable.bindings.first?.accessorBlock == nil
      }
      .flatMap { variable -> [Property] in
        let attributes = variable.attributes.compactMap { $0.as(AttributeSyntax.self) }

        guard let defaultType = variable.bindings.last?.typeAnnotation?.type else {
          return []
        }

        return variable.bindings.map { binding in
          Property(attributes: attributes, binding: binding, defaultType: defaultType)
        }
      }
  }
}

// MARK: Codable Boilerplate Code Generation
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
      for property in properties {
        if let customCodableKey = property.customCodableKey {
          "case \(property.name) = \(customCodableKey)"
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
      for property in properties {
        let key = property.name
        let type = property.type
        if let defaultValue = property.defaultValue {
          "\(key) = try container.decodeIfPresent(\(type).self, forKey: .\(key)) ?? \(defaultValue)"
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
      for property in properties {
        "try container.encode(\(property.name), forKey: .\(property.name))"
      }
    }
  }
}
