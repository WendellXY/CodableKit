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

    /// Initializes a `CodableMacro.Property` instance.
    ///
    /// - Parameters:
    ///   - attributes: The attributes associated with the macro.
    ///   - binding: The pattern binding syntax.
    ///   - type: The default type syntax. Variable Decl might not have a type annotation like in
    ///  `let a, b: String`, so we need to pass the default type.
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

extension CodableMacro.Property {
  /// Check if the property is optional.
  var isOptional: Bool {
    type.as(OptionalTypeSyntax.self) != nil || type.as(IdentifierTypeSyntax.self)?.name.text == "Optional"
  }

  /// The `CodableKey` attribute of the property, if this value is nil, the property name will be used as the key
  var customCodableKey: ExprSyntax? {
    guard
      let expr = attributes.first(where: {
        $0.attributeName.as(IdentifierTypeSyntax.self)?.description == "CodableKey"
      })?.arguments?.as(LabeledExprListSyntax.self)?.first(where: {
        $0.label == nil  // the first argument without label is the custom Codable Key
      })?.expression,
      expr.as(NilLiteralExprSyntax.self) == nil
    else {
      return nil
    }

    return expr
  }

  /// Indicates if the property should be ignored when encoding and decoding
  var ignored: Bool {
    attributes.first(where: {
      $0.attributeName.as(IdentifierTypeSyntax.self)?.description == "CodableKey"
    })?.arguments?.as(LabeledExprListSyntax.self)?.first(where: {
      $0.label?.text == "ignored"
    })?.expression.as(BooleanLiteralExprSyntax.self)?.literal.text == "true"
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
      for property in properties where !property.ignored {
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
        "try container.encode(\(property.name), forKey: .\(property.name))"
      }
    }
  }
}
