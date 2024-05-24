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

final class CodeGenCore {
  typealias Property = CodableMacro.Property

  private let messageID = MessageID(domain: "CodableKit", id: "CodableMacro")

  /// Declarations that have been prepared for code generation
  private var preparedDeclarations: Set<SyntaxIdentifier> = []
  private var properties: [SyntaxIdentifier: [CodableMacro.Property]] = [:]
  private var accessModifiers: [SyntaxIdentifier: DeclModifierSyntax] = [:]

  private let allAccessModifiers: Set<String> = [
    TokenSyntax.keyword(.open).text,
    TokenSyntax.keyword(.public).text,
    TokenSyntax.keyword(.package).text,
    TokenSyntax.keyword(.internal).text,
    TokenSyntax.keyword(.private).text,
    TokenSyntax.keyword(.fileprivate).text,
  ]
}

extension CodeGenCore {
  func properties(for declaration: some SyntaxProtocol) throws -> [Property] {
    if let properties = properties[declaration.id] {
      return properties
    }

    throw SimpleDiagnosticMessage(
      message: "Properties for declaration \(declaration) not found",
      diagnosticID: messageID,
      severity: .error
    )
  }

  func accessModifier(for declaration: some SyntaxProtocol) throws -> DeclModifierSyntax {
    if let accessModifier = accessModifiers[declaration.id] {
      return accessModifier
    }

    throw SimpleDiagnosticMessage(
      message: "Access modifier for declaration \(declaration) not found",
      diagnosticID: messageID,
      severity: .error
    )
  }
}

extension CodeGenCore {
  /// Extract all the properties from structure and add type info.
  fileprivate func extractProperties(
    from declaration: some DeclGroupSyntax
  ) throws -> [Property] {
    try declaration.memberBlock.members
      .map(\.decl)
      .compactMap { declaration in
        declaration.as(VariableDeclSyntax.self)
      }
      .filter { variable in
        variable.bindings.first?.accessorBlock == nil
      }
      .flatMap(extractProperty)
  }

  /// Extract properties from a single variable declaration
  fileprivate func extractProperty(
    from variable: VariableDeclSyntax
  ) throws -> [Property] {
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

  /// Validate that the macro is being applied to a struct declaration
  fileprivate func validateDeclaration(_ declaration: some DeclGroupSyntax) throws {
    // Struct
    if declaration.as(StructDeclSyntax.self) != nil {
      return
    }

    throw SimpleDiagnosticMessage(
      message: "Macro `CodableMacro` can only be applied to a struct",
      diagnosticID: messageID,
      severity: .error
    )
  }

  /// Prepare the code generation by extracting properties and access modifier.
  func prepareCodeGeneration(for declaration: some DeclGroupSyntax) throws {
    try validateDeclaration(declaration)

    let id = declaration.id

    defer {
      preparedDeclarations.insert(id)
    }

    // Check if properties and access modifier are already prepared

    if properties[id]?.isEmpty ?? true {
      guard preparedDeclarations.contains(id) == false else {
        throw SimpleDiagnosticMessage(
          message: "Code generation already prepared for declaration but properties not found",
          diagnosticID: messageID,
          severity: .error
        )
      }

      let extractedProperties = try extractProperties(from: declaration)
      properties[id] = extractedProperties

      if extractedProperties.isEmpty {
        throw SimpleDiagnosticMessage(
          message: "No properties found",
          diagnosticID: messageID,
          severity: .warning
        )
      }
    }

    if accessModifiers[id] == nil {
      guard preparedDeclarations.contains(id) == false else {
        throw SimpleDiagnosticMessage(
          message: "Code generation already prepared for declaration but access modifier not found",
          diagnosticID: messageID,
          severity: .error
        )
      }

      accessModifiers[id] =
        if let accessModifier = declaration.modifiers.first(where: { allAccessModifiers.contains($0.name.text) }) {
          accessModifier
        } else {
          DeclModifierSyntax(name: .keyword(.internal))
        }
    }
  }
}

extension CodeGenCore {
  func prepareCodeGeneration(for declaration: VariableDeclSyntax) throws {
    let id = declaration.id

    guard !preparedDeclarations.contains(id) else {
      throw SimpleDiagnosticMessage(
        message: "Code generation already prepared for declaration",
        diagnosticID: messageID,
        severity: .error
      )
    }

    defer {
      preparedDeclarations.insert(id)
    }

    if properties[id]?.isEmpty ?? true {
      let extractedProperties = try extractProperty(from: declaration)

      guard let extractedProperty = extractedProperties.first else {
        throw SimpleDiagnosticMessage(
          message: "No properties found",
          diagnosticID: messageID,
          severity: .warning
        )
      }

      // Since the properties extracted from the declaration share the same CodableKey, we can check the first property
      // to see if it has a custom CodableKey. And if there are some CodableKey options which support multiple pattern
      // bindings in the future, the following condition guard should not forbid them.
      if extractedProperties.count > 1 && extractedProperties.first?.customCodableKey != nil {
        throw SimpleDiagnosticMessage(
          message: "Custom Codable key not supported for multiple pattern bindings",
          diagnosticID: messageID,
          severity: .error
        )
      }

      properties[id] = [extractedProperty]
    }

    if accessModifiers[id] == nil {
      accessModifiers[id] =
        if let accessModifier = declaration.modifiers.first(where: { allAccessModifiers.contains($0.name.text) }) {
          accessModifier
        } else {
          DeclModifierSyntax(name: .keyword(.internal))
        }
    }
  }
}
