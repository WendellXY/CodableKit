//
//  EncodeKeyMacro.swift
//  CodableKit
//
//  Created by Assistant on 2025/9/7.
//

import SwiftSyntax
import SwiftSyntaxMacros

/// A peer macro that attaches encode-only customization to a property.
///
/// The macro itself emits no code; it marks the property so the codegen
/// can consult encode-specific options and/or transformer.
public struct EncodeKeyMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    _ = try CodeGenCore()
      .prepareCodeGeneration(for: declaration, in: context, with: node)
    return []
  }
}
