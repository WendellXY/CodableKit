//
//  CodableKeyMacro.swift
//  CodableKit
//
//  Created by Wendell on 3/30/24.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct CodableKeyMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Does nothing, used only to decorate members with data
    return []
  }
}
