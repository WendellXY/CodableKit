//
//  CodableHookMacro.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/10/2.
//

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CodingHookMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Validate: must attach to a function
    guard let fn = FunctionDeclSyntax(declaration) else {
      let diag = Diagnostic(
        node: node,
        message: SimpleDiagnosticMessage(
          message: "@CodableHook can only be attached to functions",
          severity: .error
        )
      )
      context.diagnose(diag)
      return []
    }

    // Validate the stage argument exists
    if node.arguments?.as(LabeledExprListSyntax.self)?.first == nil {
      let diag = Diagnostic(
        node: node,
        message: SimpleDiagnosticMessage(
          message: "@CodableHook requires a stage argument (e.g., .didDecode)",
          severity: .error
        )
      )
      context.diagnose(diag)
      return []
    }

    // Soft validation of signature based on stage token presence
    if let arg = node.arguments?.as(LabeledExprListSyntax.self)?.first?.expression {
      let stageText = arg.description
      let params = fn.signature.parameterClause.parameters
      let isStatic = fn.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" })
      if stageText.contains("didDecode") {
        // If parameter exists, prefer it to mention Decoder. If not, allow zero-parameter hooks.
        if let first = params.first, !first.type.description.contains("Decoder") {
          let diag = Diagnostic(
            node: node,
            message: SimpleDiagnosticMessage(
              message: "didDecode hooks should take a Decoder parameter",
              severity: .warning
            )
          )
          context.diagnose(diag)
        }
      } else if stageText.contains("willEncode") || stageText.contains("didEncode") {
        if let first = params.first, !first.type.description.contains("Encoder") {
          let diag = Diagnostic(
            node: node,
            message: SimpleDiagnosticMessage(
              message: "encode hooks should take an Encoder parameter",
              severity: .warning
            )
          )
          context.diagnose(diag)
        }
      } else if stageText.contains("willDecode") {
        if !isStatic {
          let diag = Diagnostic(
            node: node,
            message: SimpleDiagnosticMessage(
              message: "willDecode hooks must be static or class methods",
              severity: .warning
            )
          )
          context.diagnose(diag)
        }
        if let first = params.first, !first.type.description.contains("Decoder") {
          let diag = Diagnostic(
            node: node,
            message: SimpleDiagnosticMessage(
              message: "willDecode hooks should take a Decoder parameter",
              severity: .warning
            )
          )
          context.diagnose(diag)
        }
      }
    }

    // No peer declarations needed; this attribute is a marker used by container macros.
    return []
  }
}
