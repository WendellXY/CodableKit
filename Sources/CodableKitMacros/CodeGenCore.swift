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
}

extension CodeGenCore {
  func properties(for declaration: some DeclGroupSyntax) throws -> [Property] {
    if let properties = properties[declaration.id] {
      return properties
    }

    throw SimpleDiagnosticMessage(
      message: "Properties for declaration \(declaration) not found",
      diagnosticID: messageID,
      severity: .error
    )
  }

  func accessModifier(for declaration: some DeclGroupSyntax) throws -> DeclModifierSyntax {
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

  /// Validate that the macro is being applied to a struct declaration
  func validateDeclaration(_ declaration: some DeclGroupSyntax) throws {
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
    let id = declaration.id

    defer {
      preparedDeclarations.insert(id)
    }

    if properties[id] == nil || properties[id]?.isEmpty == true {

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

      let modifiers: Set = ["public", "private", "internal"]

      accessModifiers[id] =
        if let accessModifier = declaration.modifiers.first(where: { modifiers.contains($0.name.text) }) {
          accessModifier
        } else {
          DeclModifierSyntax(name: .keyword(.internal))
        }
    }
  }
}
