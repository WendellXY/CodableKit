//
//  DecodeKeyMacro.swift
//  CodableKit
//
//  Created by Assistant on 2025/9/7.
//

import SwiftSyntax
import SwiftSyntaxMacros

/// A peer macro that attaches decode-only customization to a property.
///
/// This macro itself does not emit any peers; it exists to make the
/// attribute available to the property extraction and codegen passes.
public struct DecodeKeyMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Ensure property metadata is captured for downstream codegen.
    _ = try CodeGenCore()
      .prepareCodeGeneration(for: declaration, in: context, with: node)
    return []
  }
}
