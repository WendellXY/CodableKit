//
//  DerivedKeyMacro.swift
//  CodableKit
//
//  Created by Wendell Wang on 2026/6/11.
//

import SwiftSyntax
import SwiftSyntaxMacros

/// The peer macro behind `@DerivedKey`.
///
/// `@DerivedKey` is primarily a marker consumed by the `@Codable`/`@Decodable` code generation:
/// the container macro skips the property in `CodingKeys`, decode, and encode, and instead emits
/// a tail assignment in `init(from:)` that feeds the already-decoded source property through the
/// transformer pipeline. This peer macro therefore generates no declarations; it only validates
/// the constraints that are visible at the property declaration itself.
public struct DerivedKeyMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Reuse the shared preparation path for structural validation (variable declarations only,
    // no accessor block, non-static).
    _ = try CodeGenCore().prepareCodeGeneration(for: declaration, in: context, with: node)

    return []
  }
}
