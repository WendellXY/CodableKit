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
      .compactMap(core.genCustomKeyVariable)
      .map(DeclSyntax.init)
  }
}
