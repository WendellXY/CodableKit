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

    // Check if the declaration is a variable declaration otherwise return an empty array
    guard var declaration = VariableDeclSyntax(declaration) else {
      return []
    }

    // If the variable is a compute property, return an empty array
    guard declaration.bindings.first?.accessorBlock == nil else {
      return []
    }

    declaration.attributes.append(.init(node))

    try core.prepareCodeGeneration(for: declaration, in: context)

    let properties = try core.properties(for: declaration, in: context)

    return properties.filter(\.shouldGenerateCustomCodingKeyVariable)
      .compactMap(core.genCustomKeyVariable)
      .map(DeclSyntax.init)
  }
}
