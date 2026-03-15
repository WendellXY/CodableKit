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
    guard let arg = node.arguments?.as(LabeledExprListSyntax.self)?.first?.expression else {
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

    let stageText = arg.description
    let params = fn.signature.parameterClause.parameters
    let isStatic = fn.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" })
    let isMutating = fn.modifiers.contains(where: { $0.name.text == "mutating" })

    func diagnose(_ message: String) {
      context.diagnose(
        Diagnostic(
          node: node,
          message: SimpleDiagnosticMessage(
            message: message,
            severity: .error
          )
        )
      )
    }

    if params.count > 1 {
      diagnose("@CodableHook methods may declare at most one parameter")
      return []
    }

    if stageText.contains("willDecode") {
      if !isStatic {
        diagnose("willDecode hooks must be static or class methods")
      }
      if let first = params.first, !first.type.description.contains("Decoder") {
        diagnose("willDecode hooks must take a Decoder parameter when a parameter is present")
      }
    } else if stageText.contains("didDecode") {
      if isStatic {
        diagnose("didDecode hooks must be instance methods")
      }
      if let first = params.first, !first.type.description.contains("Decoder") {
        diagnose("didDecode hooks must take a Decoder parameter when a parameter is present")
      }
    } else if stageText.contains("willEncode") || stageText.contains("didEncode") {
      if isStatic {
        diagnose("encode hooks must be instance methods")
      }
      if isMutating {
        diagnose("encode hooks must be nonmutating")
      }
      if let first = params.first, !first.type.description.contains("Encoder") {
        diagnose("encode hooks must take an Encoder parameter when a parameter is present")
      }
    }

    // No peer declarations needed; this attribute is a marker used by container macros.
    return []
  }
}
