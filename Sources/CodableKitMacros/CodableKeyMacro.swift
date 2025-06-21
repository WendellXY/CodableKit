//
//  CodableKeyMacro.swift
//  CodableKit
//
//  Created by Wendell on 3/30/24.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct CodableKeyMacro {
  internal static let core = CodeGenCore.shared
}

extension CodableKeyMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try core.prepareCodeGeneration(for: declaration, in: context, with: node)
      .filter(\.shouldGenerateCustomCodingKeyVariable)
      .compactMap(genCustomKeyVariable)
      .map(DeclSyntax.init)
  }
}

/// Generate the custom key variable for the property.
fileprivate func genCustomKeyVariable(for property: CodableProperty) -> VariableDeclSyntax? {
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
    modifiers: DeclModifierListSyntax([property.accessModifier]),
    bindingSpecifier: .keyword(.var),
    bindings: [pattern]
  )
}
