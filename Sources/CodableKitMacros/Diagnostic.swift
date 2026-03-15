//
//  Diagnostic.swift
//  CodableKit
//
//  Created by Wendell on 3/30/24.
//

import SwiftDiagnostics
import SwiftSyntax

struct SimpleDiagnosticMessage: DiagnosticMessage, Error {
  static let diagnosticID = MessageID(domain: "CodableKit", id: "CodableMacro")
  let message: String
  let diagnosticID: MessageID = Self.diagnosticID
  let severity: DiagnosticSeverity

  init(message: String, severity: DiagnosticSeverity = .warning) {
    self.message = message
    self.severity = severity
  }
}

extension SimpleDiagnosticMessage: FixItMessage {
  var fixItID: MessageID { diagnosticID }
}

struct SimpleFixItMessage: FixItMessage {
  let message: String
  let fixItID: MessageID

  init(message: String, fixItID: MessageID = MessageID(domain: "CodableKit", id: "CodableMacroFixIt")) {
    self.message = message
    self.fixItID = fixItID
  }
}

enum CustomError: Error, CustomStringConvertible {
  case message(String)

  var description: String {
    switch self {
    case .message(let text):
      return text
    }
  }
}

func makeDiagnostic(
  node: some SyntaxProtocol,
  message: String,
  severity: DiagnosticSeverity = .warning,
  fixIts: [FixIt] = []
) -> Diagnostic {
  Diagnostic(
    node: node,
    message: SimpleDiagnosticMessage(message: message, severity: severity),
    fixIts: fixIts
  )
}

func makeFixIt(message: String, changes: [FixIt.Change]) -> FixIt {
  FixIt(message: SimpleFixItMessage(message: message), changes: changes)
}
